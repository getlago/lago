# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::RefreshDraftAndFinalizeService do
  subject(:finalize_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:customer) { create(:customer, organization:, billing_entity:) }

    let(:invoice) do
      create(
        :invoice,
        :draft,
        :with_subscriptions,
        organization:,
        customer:,
        subscriptions: [subscription],
        currency: "EUR",
        issuing_date: Time.zone.at(timestamp).to_date
      )
    end

    let(:subscription) do
      create(
        :subscription,
        customer:,
        plan:,
        subscription_at: started_at,
        started_at:,
        created_at: started_at
      )
    end

    let(:timestamp) { Time.zone.now - 1.year }
    let(:started_at) { Time.zone.now - 2.years }
    let(:fee) { create(:fee, invoice:, subscription:) }
    let(:plan) { create(:plan, organization:, interval: "monthly") }
    let(:credit_note) { create(:credit_note, :draft, invoice:) }
    let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "count_agg") }

    let(:standard_charge) do
      create(:standard_charge, plan: subscription.plan, charge_model: "standard", billable_metric:)
    end

    let(:event) do
      create(
        :event,
        organization:,
        subscription: subscription,
        code: billable_metric.code,
        timestamp: Time.current.beginning_of_month - 2.days
      )
    end

    before do
      standard_charge
      event

      allow(SegmentTrackJob).to receive(:perform_later)
      allow(Invoices::Payments::CreateService).to receive(:call_async).and_call_original
      allow(Invoices::TransitionToFinalStatusService).to receive(:call).and_call_original
    end

    [
      :one_off,
      :add_on,
      :credit,
      :advance_charges,
      :progressive_billing
    ].each do |invoice_type|
      context "when invoice is #{invoice_type}" do
        let(:invoice) { create(:invoice, :draft, organization:, customer:, invoice_type:) }

        it "returns a forbidden failure" do
          result = finalize_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ForbiddenFailure)
        end
      end
    end

    it "marks the invoice as finalized" do
      expect { finalize_service.call }
        .to change(invoice, :status).from("draft").to("finalized")
      expect(Invoices::TransitionToFinalStatusService).to have_received(:call).with(invoice:)
    end

    context "with a non-recurring invoice" do
      let(:billing_entity) { create(:billing_entity, organization:, subscription_invoice_issuing_date_adjustment: "keep_anchor") }

      it "updates the issuing date" do
        invoice.customer.update(timezone: "America/New_York")

        freeze_time do
          current_date = Time.current.in_time_zone("America/New_York").to_date

          expect { finalize_service.call }
            .to change { invoice.reload.issuing_date }.to(current_date)
            .and change { invoice.reload.payment_due_date }.to(current_date)
        end
      end
    end

    context "with a recurring invoice" do
      let(:billing_entity) { create(:billing_entity, organization:, subscription_invoice_issuing_date_adjustment:) }

      before do
        invoice.invoice_subscriptions.first.update(recurring: true)
        invoice.customer.update(timezone: "America/New_York")
      end

      context "with issuing date adjustment set to keep_anchor" do
        let(:subscription_invoice_issuing_date_adjustment) { "keep_anchor" }

        it "does not update the issuing date" do
          expect { finalize_service.call }.not_to change { invoice.reload.issuing_date }
        end
      end

      context "with issuing date adjustment set to align_with_finalization_date" do
        let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

        it "updates the issuing date" do
          freeze_time do
            current_date = Time.current.in_time_zone("America/New_York").to_date

            expect { finalize_service.call }
              .to change { invoice.reload.issuing_date }.to(current_date)
              .and change { invoice.reload.payment_due_date }.to(current_date)
          end
        end
      end
    end

    it "generates expected fees" do
      result = finalize_service.call

      expect(result).to be_success
      expect(result.invoice.fees.charge.count).to eq(1)
      expect(result.invoice.fees.subscription.count).to eq(1)
    end

    it_behaves_like "syncs invoice" do
      let(:service_call) { finalize_service.call }
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { finalize_service.call }
    end

    it "enqueues a SendWebhookJob" do
      expect do
        finalize_service.call
      end.to have_enqueued_job(SendWebhookJob).with("invoice.created", Invoice)
    end

    it "produces an activity log" do
      described_class.call(invoice:)

      expect(Utils::ActivityLog).to have_produced("invoice.created").with(invoice)
    end

    it "enqueues GenerateDocumentsJob with email false" do
      expect do
        finalize_service.call
      end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
    end

    it "flags lifetime usage for refresh" do
      create(:usage_threshold, plan:)

      finalize_service.call

      expect(subscription.reload.lifetime_usage.recalculate_invoiced_usage).to be(true)
    end

    context "with lago_premium", :premium do
      it "enqueues GenerateDocumentsJob with email true" do
        expect do
          finalize_service.call
        end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
      end

      context "when organization does not have right email settings" do
        before { invoice.billing_entity.update!(email_settings: []) }

        it "enqueues GenerateDocumentsJob with email false" do
          expect do
            finalize_service.call
          end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
        end
      end
    end

    it "calls SegmentTrackJob" do
      invoice = finalize_service.call.invoice

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "invoice_created",
        properties: {
          organization_id: invoice.organization.id,
          invoice_id: invoice.id,
          invoice_type: invoice.invoice_type
        }
      )
    end

    it "creates a payment" do
      allow(Invoices::Payments::CreateService).to receive(:call_async)

      finalize_service.call
      expect(Invoices::Payments::CreateService).to have_received(:call_async)
    end

    context "when invoice does not exist" do
      it "returns an error" do
        result = described_class.new(invoice: nil).call
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when fees already exist" do
      it "regenerates them" do
        create(:fee, invoice:)
        result = finalize_service.call

        expect(result).to be_success
        expect(result.invoice.fees.charge.count).to eq(1)
        expect(result.invoice.fees.subscription.count).to eq(1)
      end
    end

    context "with credit notes" do
      before do
        create(:credit_note_item, credit_note:, fee:)
      end

      it "marks the credit notes as finalized" do
        expect { finalize_service.call }
          .to change { credit_note.reload.status }.from("draft").to("finalized")
      end

      it "calls SegmentTrackJob" do
        invoice = finalize_service.call.invoice
        credit_note = invoice.credit_notes.first

        expect(SegmentTrackJob).to have_received(:perform_later).with(
          membership_id: CurrentContext.membership,
          event: "credit_note_issued",
          properties: {
            organization_id: credit_note.organization.id,
            credit_note_id: credit_note.id,
            invoice_id: credit_note.invoice_id,
            credit_note_method: "credit"
          }
        )
      end

      it "enqueues a SendWebhookJob" do
        expect do
          finalize_service.call
        end.to have_enqueued_job(SendWebhookJob).with("credit_note.created", CreditNote)
      end

      it "produces an activity log" do
        result = finalize_service.call

        expect(Utils::ActivityLog).to have_produced("credit_note.created").with(result.invoice.credit_notes.first)
      end

      it "enqueues CreditNotes::GenerateDocumentsJob" do
        expect do
          finalize_service.call
        end.to have_enqueued_job(CreditNotes::GenerateDocumentsJob)
      end
    end

    context "when tax integration is set up" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

      before do
        integration_customer
        invoice.update(issuing_date: Time.current + 3.months)

        allow(Invoices::ApplyProviderTaxesService).to receive(:call).and_call_original
        allow(SendWebhookJob).to receive(:perform_later).and_call_original
        allow(Invoices::GenerateDocumentsJob).to receive(:perform_later).and_call_original
        allow(Integrations::Aggregator::Invoices::CreateJob).to receive(:perform_later).and_call_original
        allow(Invoices::Payments::CreateService).to receive(:new).and_call_original
        allow(Utils::SegmentTrack).to receive(:invoice_created).and_call_original
      end

      context "when taxes are unknown" do
        it "returns pending invoice" do
          result = finalize_service.call
          expect(invoice.reload.status).to eql("pending")
          expect(result.success?).to be(true)
        end

        it "moves invoice to pending tax state" do
          expect { finalize_service.call }.to change(invoice.reload, :tax_status).from(nil).to("pending")
        end

        it "updates fees despite error result" do
          expect { finalize_service.call }.to change(invoice.fees.charge, :count).from(0).to(1)
            .and change(invoice.fees.subscription, :count).from(0).to(1)
        end

        it "does not send any updates" do
          finalize_service.call
          expect(SendWebhookJob).not_to have_received(:perform_later).with("invoice.created", invoice)
          expect(Invoices::GenerateDocumentsJob).not_to have_received(:perform_later)
          expect(Integrations::Aggregator::Invoices::CreateJob).not_to have_received(:perform_later)
          expect(Invoices::Payments::CreateService).not_to have_received(:new)
          expect(Utils::SegmentTrack).not_to have_received(:invoice_created)
        end

        it "does not change issuing_date on the invoice" do
          expect { finalize_service.call }.not_to change(invoice, :issuing_date)
        end
      end
    end

    context "when sending an invoice that is not draft" do
      let(:invoice) do
        create(
          :invoice,
          :failed,
          :with_subscriptions,
          customer:,
          subscriptions: [subscription],
          currency: "EUR",
          issuing_date: Time.zone.at(timestamp).to_date
        )
      end

      it "does not update the invoice" do
        expect { finalize_service.call }.not_to change { invoice.reload.status }
      end
    end

    context "when invoice is a draft awaiting taxes" do
      let(:invoice) do
        create(
          :invoice,
          :draft,
          :with_subscriptions,
          organization:,
          customer:,
          subscriptions: [subscription],
          currency: "EUR",
          tax_status: :pending,
          issuing_date: Time.zone.at(timestamp).to_date
        )
      end

      it "returns a forbidden failure with cannot_finalize_with_pending_taxes code" do
        result = finalize_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("cannot_finalize_with_pending_taxes")
      end

      it "does not change the invoice status" do
        expect { finalize_service.call }.not_to change { invoice.reload.status }
      end
    end

    context "when invoice has invoice_generation_errors" do
      let(:backtrace) do
        [
          "/app/app/models/invoice.rb:432:in 'generate_organization_sequential_id'",
          "/app/app/models/invoice.rb:395:in..."
        ]
      end

      before do
        ErrorDetail.create(
          owner: invoice,
          organization: invoice.organization,
          error_code: :invoice_generation_error,
          details: {
            backtrace:,
            error: "\"#\\u003cSequenced::SequenceError: Unable to acquire lock on the database\\u003e\"",
            invoice: invoice.to_json(except: [:file, :xml_file]),
            subscriptions: invoice.subscriptions.to_json
          }
        )
      end

      context "when successfully generated the invoice" do
        it "deletes the invoice_generation_errors" do
          expect { finalize_service.call }.to change(invoice.error_details.invoice_generation_error, :count).by(-1)
        end
      end

      context "when failed to generate the invoice" do
        before do
          allow(Invoices::RefreshDraftService).to receive(:call).and_return(BaseService::Result.new.service_failure!(code: "code", message: "message"))
        end

        it "does not delete the invoice_generation_errors" do
          expect { finalize_service.call }.to raise_error(BaseService::ServiceFailure)
          expect(invoice.error_details.invoice_generation_error).to be_present
        end
      end

      context "when the backtrace is related to the billing entity" do
        let(:backtrace) do
          [
            "/app/app/models/invoice.rb:589:in 'Invoice#generate_billing_entity_sequential_id'",
            "/app/app/models/invoice.rb:568:in..."
          ]
        end

        it "deletes the invoice_generation_errors" do
          expect { finalize_service.call }.to change(invoice.error_details.invoice_generation_error, :count).by(-1)
        end
      end
    end
  end
end
