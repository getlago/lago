# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::ProviderTaxes::PullTaxesAndApplyService do
  subject(:pull_taxes_service) { described_class.new(invoice:) }

  describe "#call" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:customer) { create(:customer, organization:, billing_entity:) }

    let(:invoice) do
      create(
        :invoice,
        :pending,
        :with_tax_error,
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

    let(:integration_tax) { create(:anrok_integration, organization:) }
    let(:integration_customer_tax) { create(:anrok_customer, integration: integration_tax, customer:) }
    let(:response) { instance_double(Net::HTTPOK) }
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
    let(:endpoint_draft) { "https://api.nango.dev/v1/anrok/draft_invoices" }
    let(:body) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_multiple_fees.json")
      json = File.read(path)

      # setting item_id based on the test example
      response = JSON.parse(json)
      response["succeededInvoices"].first["fees"].first["item_id"] = fee_subscription.id
      response["succeededInvoices"].first["fees"].last["item_id"] = fee_charge.id

      response.to_json
    end
    let(:integration_collection_mapping) do
      create(
        :netsuite_collection_mapping,
        integration: integration_tax,
        mapping_type: :fallback_item,
        settings: {external_id: "1", external_account_code: "11", external_name: ""}
      )
    end

    before do
      integration_collection_mapping
      fee_subscription
      fee_charge

      allow(SegmentTrackJob).to receive(:perform_later)
      allow(Invoices::Payments::StripeCreateJob).to receive(:perform_later).and_call_original
      allow(Invoices::Payments::GocardlessCreateJob).to receive(:perform_later).and_call_original

      integration_customer_tax

      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(LagoHttpClient::Client).to receive(:new).with(endpoint_draft, retries_on: [OpenSSL::SSL::SSLError]).and_return(lago_client)
      allow(lago_client).to receive(:post_with_response).and_return(response)
      allow(response).to receive(:body).and_return(body)
    end

    context "when invoice does not exist" do
      it "returns an error" do
        result = described_class.new(invoice: nil).call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when integration customer does not exist" do
      let(:integration_customer_tax) { nil }

      it "returns an error" do
        result = pull_taxes_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("integration_customer_not_found")
      end
    end

    context "when invoice is not pending" do
      before do
        invoice.update(status: %i[finalized voided generating].sample)
      end

      it "does not change the invoice object" do
        expect { pull_taxes_service.call }.not_to change { invoice.reload.attributes }
      end

      it "returns result" do
        expect(pull_taxes_service.call).to be_success
      end
    end

    context "when invoice was finalized by a concurrent job" do
      before do
        allow(invoice).to receive(:reload).and_wrap_original do |method|
          method.call
          invoice.update(status: "finalized")
          invoice
        end
      end

      it "returns early without emitting webhook or activity log" do
        result = pull_taxes_service.call

        expect(result).to be_success
        expect(SendWebhookJob).not_to have_been_enqueued.with("invoice.created", anything)
      end
    end

    context "when taxes are fetched successfully" do
      it "marks the invoice as finalized" do
        expect { pull_taxes_service.call }
          .to change(invoice, :status).from("pending").to("finalized")
      end

      it "discards previous tax errors" do
        expect { pull_taxes_service.call }
          .to change(invoice.error_details.tax_error, :count).from(1).to(0)
      end

      context "with a non-recurring invoice" do
        let(:billing_entity) { create(:billing_entity, organization:, subscription_invoice_issuing_date_adjustment: "keep_anchor") }

        it "updates the issuing date and payment due date" do
          invoice.customer.update(timezone: "America/New_York")

          freeze_time do
            current_date = Time.current.in_time_zone("America/New_York").to_date

            expect { pull_taxes_service.call }
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
            expect { pull_taxes_service.call }.not_to change { invoice.reload.issuing_date }
          end
        end

        context "with issuing date adjustment set to align_with_finalization_date" do
          let(:subscription_invoice_issuing_date_adjustment) { "align_with_finalization_date" }

          it "updates the issuing date and payment due date" do
            freeze_time do
              current_date = Time.current.in_time_zone("America/New_York").to_date

              expect { pull_taxes_service.call }
                .to change { invoice.reload.issuing_date }.to(current_date)
                .and change { invoice.reload.payment_due_date }.to(current_date)
            end
          end
        end
      end

      it "generates invoice number" do
        customer_slug = "#{billing_entity.document_number_prefix}-#{format("%03d", customer.sequential_id)}"
        sequential_id = customer.invoices.where.not(id: invoice.id).order(created_at: :desc).first&.sequential_id || 0

        expect { pull_taxes_service.call }
          .to change { invoice.reload.number }
          .from("#{billing_entity.document_number_prefix}-DRAFT")
          .to("#{customer_slug}-#{format("%03d", sequential_id + 1)}")
      end

      it "generates expected invoice totals" do
        result = pull_taxes_service.call

        expect(result).to be_success
        expect(result.invoice.fees.charge.count).to eq(1)
        expect(result.invoice.fees.subscription.count).to eq(1)

        expect(result.invoice.currency).to eq("EUR")
        expect(result.invoice.fees_amount_cents).to eq(3_000)

        expect(result.invoice.taxes_amount_cents).to eq(350)
        expect(result.invoice.taxes_rate.round(2)).to eq(11.67) # (0.667 * 10) + (0.333 * 15)
        expect(result.invoice.applied_taxes.count).to eq(2)

        expect(result.invoice.total_amount_cents).to eq(3_350)
      end

      it_behaves_like "syncs invoice" do
        let(:service_call) { pull_taxes_service.call }
      end

      it "enqueues a SendWebhookJob" do
        expect do
          pull_taxes_service.call
        end.to have_enqueued_job(SendWebhookJob).with("invoice.created", Invoice)
      end

      it "produces an activity log" do
        described_class.call(invoice:)

        expect(Utils::ActivityLog).to have_produced("invoice.created").with(invoice)
      end

      it "does not enqueue invoice.ready_to_finalize" do
        expect do
          pull_taxes_service.call
        end.not_to have_enqueued_job(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
      end

      it "enqueues GenerateDocumentsJob with email false" do
        expect do
          pull_taxes_service.call
        end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
      end

      context "with lago_premium", :premium do
        it "enqueues GenerateDocumentsJob with email true" do
          expect do
            pull_taxes_service.call
          end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
        end

        context "when billing entity does not have right email settings" do
          before { invoice.billing_entity.update!(email_settings: []) }

          it "enqueues GenerateDocumentsJob with email false" do
            expect do
              pull_taxes_service.call
            end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
          end
        end
      end

      it "calls SegmentTrackJob" do
        invoice = pull_taxes_service.call.invoice

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

        pull_taxes_service.call
        expect(Invoices::Payments::CreateService).to have_received(:call_async)
      end

      context "with credit notes" do
        let(:credit_note) do
          create(
            :credit_note,
            customer:,
            total_amount_cents: 10,
            total_amount_currency: "EUR",
            balance_amount_cents: 10,
            balance_amount_currency: "EUR",
            credit_amount_cents: 10,
            credit_amount_currency: "EUR"
          )
        end

        before { credit_note }

        it "updates the invoice accordingly" do
          result = pull_taxes_service.call

          expect(result).to be_success
          expect(result.invoice.fees_amount_cents).to eq(3_000)
          expect(result.invoice.taxes_amount_cents).to eq(350)
          expect(result.invoice.total_amount_cents).to eq(3_340)
          expect(result.invoice.credits.count).to eq(1)

          credit = result.invoice.credits.first
          expect(credit.credit_note).to eq(credit_note)
          expect(credit.amount_cents).to eq(10)
        end

        context "when invoice type is one_off" do
          before do
            invoice.update!(invoice_type: :one_off)
          end

          it "does not apply credit note" do
            result = pull_taxes_service.call

            expect(result).to be_success
            expect(result.invoice.fees_amount_cents).to eq(3_000)
            expect(result.invoice.taxes_amount_cents).to eq(350)
            expect(result.invoice.total_amount_cents).to eq(3_350)
            expect(result.invoice.credits.count).to eq(0)
          end
        end
      end

      context "when status is draft" do
        before do
          invoice.update!(status: :draft)
        end

        it "marks the invoice as draft" do
          expect { pull_taxes_service.call }
            .not_to change(invoice, :status).from("draft")
        end

        it "discards previous tax errors" do
          expect { pull_taxes_service.call }
            .to change(invoice.error_details.tax_error, :count).from(1).to(0)
        end

        it "does not generate invoice number" do
          expect { pull_taxes_service.call }
            .not_to change { invoice.reload.number }
            .from("#{billing_entity.document_number_prefix}-DRAFT")
        end

        it "generates expected invoice totals" do
          result = pull_taxes_service.call

          expect(result).to be_success
          expect(result.invoice.fees.charge.count).to eq(1)
          expect(result.invoice.fees.subscription.count).to eq(1)

          expect(result.invoice.currency).to eq("EUR")
          expect(result.invoice.fees_amount_cents).to eq(3_000)

          expect(result.invoice.taxes_amount_cents).to eq(350)
          expect(result.invoice.taxes_rate.round(2)).to eq(11.67) # (0.667 * 10) + (0.333 * 15)
          expect(result.invoice.applied_taxes.count).to eq(2)

          expect(result.invoice.total_amount_cents).to eq(3_350)
        end

        it "does not enqueue a SendWebhookJob" do
          expect do
            pull_taxes_service.call
          end.not_to have_enqueued_job(SendWebhookJob).with("invoice.created", Invoice)
        end

        it "enqueues a SendWebhookJob for invoice.ready_to_finalize" do
          expect do
            pull_taxes_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
        end

        it "produces an activity log for invoice.ready_to_finalize" do
          pull_taxes_service.call
          expect(Utils::ActivityLog).to have_produced("invoice.ready_to_finalize").with(invoice)
        end

        it "does not create a payment" do
          allow(Invoices::Payments::CreateService).to receive(:call_async)

          pull_taxes_service.call
          expect(Invoices::Payments::CreateService).not_to have_received(:call_async)
        end

        context "with credit notes" do
          let(:credit_note) do
            create(
              :credit_note,
              customer:,
              total_amount_cents: 10,
              total_amount_currency: "EUR",
              balance_amount_cents: 10,
              balance_amount_currency: "EUR",
              credit_amount_cents: 10,
              credit_amount_currency: "EUR"
            )
          end

          before { credit_note }

          it "does not apply credit note" do
            result = pull_taxes_service.call

            expect(result).to be_success
            expect(result.invoice.fees_amount_cents).to eq(3_000)
            expect(result.invoice.taxes_amount_cents).to eq(350)
            expect(result.invoice.total_amount_cents).to eq(3_350)
            expect(result.invoice.credits.count).to eq(0)
          end
        end
      end
    end

    context "when failed to fetch taxes" do
      let(:body) do
        path = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")
        File.read(path)
      end

      it "puts invoice in failed status" do
        result = pull_taxes_service.call

        expect(result).to be_success
        expect(invoice.reload.status).to eq("failed")
      end

      it "resolves old tax error and creates new one" do
        old_error_id = invoice.reload.error_details.last.id
        pull_taxes_service.call
        expect(invoice.error_details.tax_error.last.id).not_to eql(old_error_id)
        expect(invoice.error_details.tax_error.count).to be(1)
        expect(invoice.error_details.tax_error.order(created_at: :asc).last.discarded?).to be(false)
      end

      it "does not enqueue invoice.ready_to_finalize" do
        expect do
          pull_taxes_service.call
        end.not_to have_enqueued_job(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
      end

      context "with api limit error" do
        let(:body) do
          p = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/api_limit_response.json")
          File.read(p)
        end

        it "raises ServerContentionError so the job can retry" do
          expect { pull_taxes_service.call }.to raise_error(Integrations::Aggregator::ServerContentionError)
        end

        it "does not change the invoice status" do
          expect { pull_taxes_service.call }.to raise_error(Integrations::Aggregator::ServerContentionError)
          expect(invoice.reload.status).not_to eq("failed")
        end
      end

      context "with script error" do
        let(:invoice) do
          create(
            :invoice,
            :draft,
            :with_tax_error,
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

        let(:body) do
          p = Rails.root.join("spec/fixtures/integration_aggregator/error_script_response.json")
          File.read(p)
        end

        before do
          allow(lago_client).to receive(:post_with_response)
            .and_raise(::LagoHttpClient::HttpError.new(500, body, endpoint_draft, response_headers: {}))
        end

        it "puts invoice in failed status" do
          result = pull_taxes_service.call

          expect(result).to be_success
          expect(invoice.reload.status).to eq("draft")
          expect(invoice.tax_status).to eq("failed")
        end

        it "resolves old tax error and creates new one" do
          old_error_id = invoice.reload.error_details.last.id

          pull_taxes_service.call

          expect(invoice.error_details.tax_error.last.id).not_to eql(old_error_id)
          expect(invoice.error_details.tax_error.count).to be(1)
          expect(invoice.error_details.tax_error.order(created_at: :asc).last.discarded?).to be(false)
          expect(invoice.error_details.tax_error.order(created_at: :asc).last.details["tax_error"])
            .to eq("action_script_failure")
          expect(invoice.error_details.tax_error.order(created_at: :asc).last.details["tax_error_message"])
            .to eq("Error starting integration 'netsuite-customer-create': {\n  \"name\": \"TRPCClientError\",\n  \"message\": \"fetch failed\"\n}")
        end

        it "enqueues a SendWebhookJob for invoice.ready_to_finalize" do
          expect do
            pull_taxes_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
        end

        it "produces an activity log for invoice.ready_to_finalize" do
          pull_taxes_service.call
          expect(Utils::ActivityLog).to have_produced("invoice.ready_to_finalize").with(invoice)
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
        create(:invoice, :with_subscriptions, customer:, organization:, status: :open,
          currency: "EUR", subscriptions: [subscription])
      end

      before do
        invoice.update!(tax_status: :pending)
      end

      it "allows processing and triggers payment only" do
        allow(Invoices::Payments::CreateService).to receive(:call_async)

        result = pull_taxes_service.call

        expect(result).to be_success
        expect(Invoices::Payments::CreateService).to have_received(:call_async)
        expect(SendWebhookJob).not_to have_been_enqueued.with("invoice.created", anything)
      end

      it "calls Integrations::Aggregator::Taxes::Invoices::CreateDraftService" do
        allow(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to receive(:call).and_call_original
        allow(Integrations::Aggregator::Taxes::Invoices::CreateService).to receive(:call).and_call_original

        pull_taxes_service.call

        expect(Integrations::Aggregator::Taxes::Invoices::CreateDraftService).to have_received(:call).with(invoice:, fees: invoice.fees)
        expect(Integrations::Aggregator::Taxes::Invoices::CreateService).not_to have_received(:call)
      end

      context "when invoice total is zero after tax computation" do
        let(:rule) { subscription.activation_rules.payment.sole }
        let(:fee_subscription) do
          create(:fee, invoice:, subscription:, fee_type: :subscription, amount_cents: 0)
        end
        let(:fee_charge) do
          create(:fee, invoice:, charge:, fee_type: :charge, total_aggregated_units: 0, amount_cents: 0)
        end
        let(:body) do
          {
            succeededInvoices: [{
              id: invoice.id,
              issuing_date: Time.current.to_date.iso8601,
              sub_total_excluding_taxes: 0,
              taxes_amount_cents: 0,
              currency: "EUR",
              fees: [
                {item_id: fee_subscription.id, amount_cents: 0, tax_amount_cents: 0, tax_breakdown: []},
                {item_id: fee_charge.id, amount_cents: 0, tax_amount_cents: 0, tax_breakdown: []}
              ]
            }],
            failedInvoices: []
          }.to_json
        end

        it "marks the payment activation rule as satisfied" do
          pull_taxes_service.call

          expect(rule.reload).to be_satisfied
        end

        it "activates the subscription" do
          pull_taxes_service.call

          expect(subscription.reload).to be_active
        end
      end
    end
  end
end
