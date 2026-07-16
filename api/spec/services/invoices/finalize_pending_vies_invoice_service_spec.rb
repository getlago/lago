# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::FinalizePendingViesInvoiceService do
  subject(:finalize_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:customer) { create(:customer, organization:, billing_entity:) }

    let(:invoice) do
      create(
        :invoice,
        :pending,
        :with_subscriptions,
        customer:,
        billing_entity:,
        organization:,
        subscriptions: [subscription],
        currency: "EUR",
        tax_status: "pending",
        issuing_date: Time.zone.at(timestamp).to_date
      )
    end

    let(:subscription) do
      create(
        :subscription,
        plan:,
        subscription_at: started_at,
        started_at:,
        created_at: started_at
      )
    end

    let(:timestamp) { Time.zone.now - 1.year }
    let(:started_at) { Time.zone.now - 2.years }
    let(:plan) { create(:plan, organization:, interval: "monthly") }
    let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
    let(:charge) { create(:standard_charge, plan: subscription.plan, charge_model: "standard", billable_metric:) }

    let(:fee_subscription) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: :subscription,
        amount_cents: 2_000
      )
    end
    let(:fee_charge) do
      create(
        :fee,
        invoice:,
        charge:,
        fee_type: :charge,
        total_aggregated_units: 100,
        amount_cents: 1_000
      )
    end

    before do
      fee_subscription
      fee_charge
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    context "when invoice does not exist" do
      it "returns an error" do
        result = described_class.new(invoice: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when invoice is not pending" do
      before { invoice.update!(status: :finalized) }

      it "does not change the invoice" do
        expect { finalize_service.call }.not_to change { invoice.reload.attributes }
      end

      it "returns success" do
        expect(finalize_service.call).to be_success
      end
    end

    context "when invoice tax_status is not pending" do
      before { invoice.update!(tax_status: "succeeded") }

      it "does not change the invoice" do
        expect { finalize_service.call }.not_to change { invoice.reload.attributes }
      end

      it "returns success" do
        expect(finalize_service.call).to be_success
      end
    end

    context "when customer has tax provider" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

      before { integration_customer }

      it "does not change the invoice" do
        expect { finalize_service.call }.not_to change { invoice.reload.attributes }
      end

      it "returns success" do
        expect(finalize_service.call).to be_success
      end
    end

    context "when VIES check is still in progress" do
      let(:billing_entity) { create(:billing_entity, organization:, eu_tax_management: true) }
      let(:pending_vies_check) { create(:pending_vies_check, customer:) }

      before { pending_vies_check }

      it "does not change the invoice" do
        expect { finalize_service.call }.not_to change { invoice.reload.attributes }
      end

      it "returns success" do
        expect(finalize_service.call).to be_success
      end
    end

    context "when invoice is finalized successfully" do
      it "changes status from pending to finalized" do
        expect { finalize_service.call }
          .to change { invoice.reload.status }.from("pending").to("finalized")
      end

      it "sets tax_status to succeeded" do
        expect { finalize_service.call }
          .to change { invoice.reload.tax_status }.from("pending").to("succeeded")
      end

      it "computes invoice amounts" do
        finalize_service.call

        invoice.reload
        expect(invoice.fees_amount_cents).to eq(3_000)
        expect(invoice.total_amount_cents).to be_positive
      end

      it "applies invoice custom sections" do
        allow(Invoices::ApplyInvoiceCustomSectionsService).to receive(:call)

        finalize_service.call

        expect(Invoices::ApplyInvoiceCustomSectionsService).to have_received(:call).with(invoice:)
      end

      it "sets payment_status to pending when total is positive" do
        finalize_service.call

        expect(invoice.reload.payment_status).to eq("pending")
      end

      it "enqueues SendWebhookJob" do
        expect { finalize_service.call }
          .to have_enqueued_job(SendWebhookJob).with("invoice.created", invoice)
      end

      it "produces an activity log" do
        finalize_service.call

        expect(Utils::ActivityLog).to have_produced("invoice.created").with(invoice)
      end

      it "enqueues Invoices::GenerateDocumentsJob" do
        expect { finalize_service.call }
          .to have_enqueued_job(Invoices::GenerateDocumentsJob).with(invoice:, notify: false)
      end

      it "calls Invoices::Payments::CreateService" do
        allow(Invoices::Payments::CreateService).to receive(:call_async)

        finalize_service.call

        expect(Invoices::Payments::CreateService).to have_received(:call_async).with(invoice:, payment_method_params: {})
      end

      it "returns the invoice in result" do
        result = finalize_service.call

        expect(result).to be_success
        expect(result.invoice).to eq(invoice)
      end

      context "when customer has accounting integration" do
        let(:netsuite_integration) { create(:netsuite_integration, organization:, sync_invoices: true) }
        let(:netsuite_customer) { create(:netsuite_customer, integration: netsuite_integration, customer:) }

        before { netsuite_customer }

        it "enqueues Integrations::Aggregator::Invoices::CreateJob" do
          expect { finalize_service.call }
            .to have_enqueued_job(Integrations::Aggregator::Invoices::CreateJob).with(invoice:)
        end
      end

      context "when customer has hubspot integration" do
        let(:hubspot_integration) { create(:hubspot_integration, organization:, sync_invoices: true) }
        let(:hubspot_customer) { create(:hubspot_customer, integration: hubspot_integration, customer:) }

        before { hubspot_customer }

        it "enqueues Integrations::Aggregator::Invoices::Hubspot::CreateJob" do
          expect { finalize_service.call }
            .to have_enqueued_job(Integrations::Aggregator::Invoices::Hubspot::CreateJob).with(invoice:)
        end
      end

      context "when total_amount_cents is zero" do
        let(:fee_subscription) do
          create(:fee, invoice:, subscription:, fee_type: :subscription, amount_cents: 0)
        end
        let(:fee_charge) { nil }

        it "sets payment_status to succeeded" do
          finalize_service.call

          expect(invoice.reload.payment_status).to eq("succeeded")
        end
      end
    end

    context "with issuing_date handling" do
      let(:original_issuing_date) { invoice.issuing_date }

      context "when recurring invoice with keep_anchor adjustment" do
        before do
          # rubocop:disable Rails/SkipsModelValidations
          invoice.invoice_subscriptions.update_all(recurring: true)
          # rubocop:enable Rails/SkipsModelValidations
          customer.update!(subscription_invoice_issuing_date_adjustment: "keep_anchor")
        end

        it "keeps the original issuing_date" do
          finalize_service.call

          expect(invoice.reload.issuing_date).to eq(original_issuing_date)
        end
      end

      context "when not keeping anchor" do
        before do
          # rubocop:disable Rails/SkipsModelValidations
          invoice.invoice_subscriptions.update_all(recurring: false)
          # rubocop:enable Rails/SkipsModelValidations
        end

        it "updates issuing_date to current date" do
          freeze_time do
            finalize_service.call

            expect(invoice.reload.issuing_date).to eq(Time.current.to_date)
          end
        end
      end
    end

    context "with payment_due_date" do
      before do
        customer.update!(net_payment_term: 30)
      end

      it "sets payment_due_date based on issuing_date and net_payment_term" do
        freeze_time do
          finalize_service.call

          expect(invoice.reload.payment_due_date).to eq(Time.current.to_date + 30.days)
        end
      end
    end

    context "when invoice is one-off" do
      let(:add_on) { create(:add_on, organization:, amount_cents: 5000) }

      let(:invoice) do
        create(
          :invoice,
          :pending,
          customer:,
          billing_entity:,
          organization:,
          invoice_type: :one_off,
          currency: "EUR",
          tax_status: "pending",
          issuing_date: Time.zone.at(timestamp).to_date
        )
      end

      let(:fee_subscription) { nil }
      let(:fee_charge) { nil }

      let(:fee_add_on) do
        create(
          :fee,
          invoice:,
          add_on:,
          fee_type: :add_on,
          invoiceable: add_on,
          amount_cents: 5000
        )
      end

      before do
        fee_add_on
        allow(SegmentTrackJob).to receive(:perform_later)
      end

      it "changes status from pending to finalized" do
        expect { finalize_service.call }
          .to change { invoice.reload.status }.from("pending").to("finalized")
      end

      it "enqueues SendWebhookJob with one_off webhook type" do
        expect { finalize_service.call }
          .to have_enqueued_job(SendWebhookJob).with("invoice.one_off_created", invoice)
      end

      it "produces an activity log with one_off action" do
        finalize_service.call

        expect(Utils::ActivityLog).to have_produced("invoice.one_off_created").with(invoice)
      end

      it "does not apply credit note credits" do
        finalize_service.call

        expect(invoice.reload.credits.credit_note_kind).to be_empty
      end

      it "does not apply prepaid credits" do
        finalize_service.call

        expect(invoice.reload.wallet_transactions).to be_empty
      end

      context "when invoice has a stored payment method" do
        let(:payment_method) { create(:payment_method, customer:) }

        let(:invoice) do
          create(
            :invoice,
            :pending,
            customer:,
            billing_entity:,
            organization:,
            invoice_type: :one_off,
            currency: "EUR",
            tax_status: "pending",
            issuing_date: Time.zone.at(timestamp).to_date,
            payment_method:
          )
        end

        it "passes payment_method_params to CreateService" do
          allow(Invoices::Payments::CreateService).to receive(:call_async)

          finalize_service.call

          expect(Invoices::Payments::CreateService).to have_received(:call_async)
            .with(invoice:, payment_method_params: {payment_method_id: payment_method.id})
        end
      end

      context "when invoice has skip_automatic_payment set" do
        let(:invoice) do
          create(
            :invoice,
            :pending,
            customer:,
            billing_entity:,
            organization:,
            invoice_type: :one_off,
            currency: "EUR",
            tax_status: "pending",
            issuing_date: Time.zone.at(timestamp).to_date,
            skip_automatic_payment: true
          )
        end

        it "does not create a payment" do
          allow(Invoices::Payments::CreateService).to receive(:call_async)

          finalize_service.call

          expect(Invoices::Payments::CreateService).not_to have_received(:call_async)
        end
      end
    end

    context "when invoice is pay-in-advance fixed charges" do
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charge) { create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"}) }

      let(:invoice) do
        create(
          :invoice,
          :pending,
          customer:,
          billing_entity:,
          organization:,
          currency: "EUR",
          tax_status: "pending",
          issuing_date: Time.zone.at(timestamp).to_date
        )
      end

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          :boundaries,
          invoice:,
          subscription:,
          invoicing_reason: :in_advance_charge
        )
      end

      # Override outer let blocks to prevent creating subscription/charge fees
      let(:fee_subscription) { nil }
      let(:fee_charge) { nil }

      let(:fee_fixed_charge) do
        create(
          :fee,
          invoice:,
          subscription:,
          fixed_charge:,
          invoiceable: fixed_charge,
          fee_type: :fixed_charge,
          pay_in_advance: true,
          amount_cents: 10_000,
          units: 10
        )
      end

      before do
        invoice_subscription
        fee_fixed_charge
        allow(SegmentTrackJob).to receive(:perform_later)
      end

      it "changes status from pending to finalized" do
        expect { finalize_service.call }
          .to change { invoice.reload.status }.from("pending").to("finalized")
      end

      it "sets tax_status to succeeded" do
        expect { finalize_service.call }
          .to change { invoice.reload.tax_status }.from("pending").to("succeeded")
      end

      it "computes invoice amounts correctly" do
        finalize_service.call

        invoice.reload
        expect(invoice.fees_amount_cents).to eq(10_000)
        expect(invoice.total_amount_cents).to be_positive
      end

      it "enqueues SendWebhookJob" do
        expect { finalize_service.call }
          .to have_enqueued_job(SendWebhookJob).with("invoice.created", invoice)
      end

      it "calls Invoices::Payments::CreateService" do
        allow(Invoices::Payments::CreateService).to receive(:call_async)

        finalize_service.call

        expect(Invoices::Payments::CreateService).to have_received(:call_async).with(invoice:, payment_method_params: {})
      end

      it "updates issuing_date to current date (not keeping anchor for non-recurring)" do
        freeze_time do
          finalize_service.call

          expect(invoice.reload.issuing_date).to eq(Time.current.to_date)
        end
      end

      context "with credit note credits available" do
        let(:credit_note) do
          create(
            :credit_note,
            customer:,
            balance_amount_cents: 500,
            credit_amount_cents: 500,
            status: :finalized,
            credit_status: :available
          )
        end

        before { credit_note }

        it "applies credit note credits to the invoice" do
          finalize_service.call

          invoice.reload
          expect(invoice.credits.credit_note_kind.first.credit_note).to eq(credit_note)
          expect(invoice.credit_notes_amount_cents).to eq(500)
        end
      end

      context "with active wallet" do
        let(:wallet) { create(:wallet, :with_inbound_transaction, customer:, balance_cents: 1000, credits_balance: 10.0) }

        before { wallet }

        it "applies prepaid credits to the invoice" do
          finalize_service.call

          invoice.reload
          expect(invoice.wallet_transactions.first.wallet).to eq(wallet)
          expect(invoice.prepaid_credit_amount_cents).to eq(1000)
        end
      end
    end

    context "when invoice is subscription_gated" do
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: :payment, timeout_hours: 48, status: :pending}],
          customer:, organization:)
      end
      let(:invoice) do
        create(
          :invoice,
          :with_subscriptions,
          customer:,
          organization:,
          billing_entity:,
          status: :open,
          tax_status: :pending,
          currency: "EUR",
          subscriptions: [subscription]
        )
      end

      it "allows processing and triggers payment only" do
        allow(Invoices::Payments::CreateService).to receive(:call_async)

        finalize_service.call

        expect(Invoices::Payments::CreateService).to have_received(:call_async)
        expect(SendWebhookJob).not_to have_been_enqueued.with("invoice.created", anything)
      end

      context "when invoice total is zero after tax computation" do
        let(:rule) { subscription.activation_rules.payment.sole }
        let(:fee_subscription) do
          create(:fee, invoice:, subscription:, fee_type: :subscription, amount_cents: 0)
        end
        let(:fee_charge) do
          create(:fee, invoice:, charge:, fee_type: :charge, total_aggregated_units: 0, amount_cents: 0)
        end

        it "marks the payment activation rule as satisfied" do
          finalize_service.call

          expect(rule.reload).to be_satisfied
        end

        it "activates the subscription" do
          finalize_service.call

          expect(subscription.reload).to be_active
        end
      end
    end
  end
end
