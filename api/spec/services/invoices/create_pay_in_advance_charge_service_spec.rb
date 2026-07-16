# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreatePayInAdvanceChargeService do
  subject(:invoice_service) do
    described_class.new(charge:, event:, timestamp: timestamp.to_i)
  end

  let(:timestamp) { Time.zone.now.beginning_of_month }
  let(:organization) { create(:organization) }
  let(:billing_entity) { customer.billing_entity }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:charge) { create(:standard_charge, :pay_in_advance, billable_metric:, plan:) }
  let(:charge_filter) { nil }

  let(:email_settings) { ["invoice.finalized", "credit_note.created"] }

  let(:event) do
    Events::CommonFactory.new_instance(
      source: create(
        :event,
        external_subscription_id: subscription.external_id,
        external_customer_id: customer.external_id,
        organization_id: organization.id
      )
    )
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:)
    billing_entity.update!(email_settings:)
  end

  describe "#call" do
    let(:aggregation_result) do
      BaseService::Result.new.tap do |result|
        result.aggregation = 9
        result.count = 4
        result.options = {}
      end
    end

    let(:charge_result) do
      BaseService::Result.new.tap do |result|
        result.amount = 10
        result.precise_amount = 10.0
        result.unit_amount = 0.01111111111
        result.count = 1
        result.units = 9
        result.amount_details = {}
      end
    end

    before do
      allow(Charges::PayInAdvanceAggregationService).to receive(:call)
        .with(charge:, boundaries: BillingPeriodBoundaries, properties: Hash, event:, charge_filter:)
        .and_return(aggregation_result)

      allow(Charges::ApplyPayInAdvanceChargeModelService).to receive(:call)
        .with(charge:, aggregation_result:, properties: Hash)
        .and_return(charge_result)

      allow(Invoices::TransitionToFinalStatusService).to receive(:call).and_call_original
    end

    it "creates an invoice" do
      result = invoice_service.call

      expect(result).to be_success

      expect(result.invoice.issuing_date.to_date).to eq(timestamp)
      expect(result.invoice.payment_due_date.to_date).to eq(timestamp)
      expect(result.invoice.organization_id).to eq(organization.id)
      expect(result.invoice.customer_id).to eq(customer.id)
      expect(result.invoice.invoice_type).to eq("subscription")
      expect(result.invoice.payment_status).to eq("pending")

      expect(result.invoice.fees.where(fee_type: :charge).count).to eq(1)
      expect(result.invoice.fees.first).to have_attributes(
        subscription:,
        charge:,
        amount_cents: 10,
        precise_amount_cents: 10.0,
        amount_currency: "EUR",
        taxes_rate: 20.0,
        taxes_amount_cents: 2,
        taxes_precise_amount_cents: 2.0,
        fee_type: "charge",
        pay_in_advance: true,
        invoiceable: charge,
        units: 9,
        properties: Hash,
        events_count: 1,
        charge_filter: nil,
        pay_in_advance_event_id: event.id,
        payment_status: "pending",
        unit_amount_cents: 1,
        precise_unit_amount: 0.01111111111
      )

      expect(result.invoice.currency).to eq(subscription.plan_amount_currency)
      expect(result.invoice.fees_amount_cents).to eq(10)

      expect(result.invoice.taxes_amount_cents).to eq(2)
      expect(result.invoice.taxes_rate).to eq(20)
      expect(result.invoice.applied_taxes.count).to eq(1)

      expect(result.invoice.total_amount_cents).to eq(12)

      expect(Invoices::TransitionToFinalStatusService).to have_received(:call).with(invoice: result.invoice)
      expect(result.invoice).to be_finalized
    end

    it "creates InvoiceSubscription object" do
      expect { invoice_service.call.invoice }.to change(InvoiceSubscription, :count).by(1)
    end

    context "with billing entity resolution" do
      it "stamps the customer's billing_entity when subscription has none" do
        invoice = invoice_service.call.invoice

        expect(invoice.billing_entity).to eq(customer.billing_entity)
      end

      context "when subscription has its own billing_entity" do
        let(:other_billing_entity) { create(:billing_entity, organization:) }

        before { subscription.update!(billing_entity: other_billing_entity) }

        it "stamps the subscription's billing_entity on the invoice" do
          invoice = invoice_service.call.invoice

          expect(invoice.billing_entity).to eq(other_billing_entity)
        end
      end
    end

    it "calls SegmentTrackJob" do
      invoice = invoice_service.call.invoice

      expect(SegmentTrackJob).to have_been_enqueued.with(
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

      invoice_service.call

      expect(Invoices::Payments::CreateService).to have_received(:call_async)
    end

    it "enqueues a SendWebhookJob for the invoice" do
      expect do
        invoice_service.call
      end.to have_enqueued_job(SendWebhookJob).with("invoice.created", Invoice)
    end

    it "enqueues a SendWebhookJob for the fees" do
      expect do
        invoice_service.call
      end.to have_enqueued_job(SendWebhookJob).with("fee.created", Fee)
    end

    it "produces an activity log" do
      invoice = described_class.call(charge:, event:, timestamp: timestamp.to_i).invoice

      expect(Utils::ActivityLog).to have_produced("invoice.created").with(invoice)
    end

    context "when the subscription has its own billing entity (different from the customer's)" do
      let(:customer_billing_entity) { create(:billing_entity, organization:, code: "acme_us") }
      let(:subscription_billing_entity) { create(:billing_entity, organization:, code: "acme_eu") }
      let(:customer) { create(:customer, organization:, billing_entity: customer_billing_entity) }
      let(:subscription) { create(:subscription, customer:, plan:, billing_entity: subscription_billing_entity) }

      it "stamps the invoice with the subscription's billing entity, not the customer's" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.billing_entity_id).to eq(subscription_billing_entity.id)
        expect(result.invoice.billing_entity_id).not_to eq(customer_billing_entity.id)
      end
    end

    context "when the subscription has no explicit billing entity" do
      let(:customer_billing_entity) { create(:billing_entity, organization:, code: "acme_us") }
      let(:customer) { create(:customer, organization:, billing_entity: customer_billing_entity) }
      let(:subscription) { create(:subscription, customer:, plan:, billing_entity: nil) }

      it "falls back to the customer's billing entity" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.billing_entity_id).to eq(customer_billing_entity.id)
      end
    end

    it "enqueues GenerateDocumentsJob with email false" do
      expect do
        invoice_service.call
      end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
    end

    context "with lago_premium", :premium do
      it "enqueues GenerateDocumentsJob with email true" do
        expect do
          invoice_service.call
        end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
      end

      context "when organization does not have right email settings" do
        let(:email_settings) { [] }

        it "enqueues GenerateDocumentsJob with email false" do
          expect do
            invoice_service.call
          end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
        end
      end
    end

    context "with customer timezone" do
      let(:customer) { create(:customer, organization:, timezone: "America/Los_Angeles") }
      let(:timestamp) { DateTime.parse("2022-11-25 01:00:00") }

      it "assigns the issuing date in the customer timezone" do
        result = invoice_service.call

        expect(result.invoice.issuing_date.to_s).to eq("2022-11-24")
        expect(result.invoice.payment_due_date.to_s).to eq("2022-11-24")
      end
    end

    context "when there is tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
      let(:response) { instance_double(Net::HTTPOK) }
      let(:lago_client) { instance_double(LagoHttpClient::Client) }
      let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
      let(:body) do
        p = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json")
        File.read(p)
      end
      let(:integration_collection_mapping) do
        create(
          :netsuite_collection_mapping,
          integration:,
          mapping_type: :fallback_item,
          settings: {external_id: "1", external_account_code: "11", external_name: ""}
        )
      end

      before do
        integration_collection_mapping
        integration_customer

        allow(LagoHttpClient::Client).to receive(:new)
          .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
          .and_return(lago_client)
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(body)
        allow_any_instance_of(Fee).to receive(:id).and_return("lago_fee_id") # rubocop:disable RSpec/AnyInstance
      end

      it "creates a pending invoice for async tax resolution" do
        result = invoice_service.call

        expect(result).to be_success

        expect(result.invoice.status).to eq("pending")
        expect(result.invoice.tax_status).to eq("pending")
        expect(result.invoice.fees_amount_cents).to eq(10)
      end

      it "enqueues fee webhooks but not invoice webhooks" do
        invoice_service.call

        expect(SendWebhookJob).to have_been_enqueued.with("fee.created", anything)
        expect(SendWebhookJob).not_to have_been_enqueued.with("invoice.created", anything)
      end

      context "with custom sections applied at the billing entity level" do
        let(:custom_section) { create(:invoice_custom_section, organization:) }

        before do
          create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: custom_section)
        end

        it "applies the custom sections even though tax resolution is deferred" do
          result = invoice_service.call

          expect(result).to be_success
          expect(result.invoice.status).to eq("pending")
          expect(result.invoice.applied_invoice_custom_sections.pluck(:code)).to eq([custom_section.code])
        end
      end
    end

    context "with grace period" do
      let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
      let(:timestamp) { DateTime.parse("2022-11-25 08:00:00") }

      it "assigns the correct issuing date" do
        result = invoice_service.call

        expect(result.invoice.issuing_date.to_s).to eq("2022-11-25")
      end
    end

    context "when customer has wallet with positive balance" do
      before { create(:wallet, :with_inbound_transaction, customer:, balance_cents: 100, credits_balance: 100) }

      it "uses the prepaid credits" do
        allow(Credits::AppliedPrepaidCreditsService).to receive(:call).and_call_original

        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.total_amount_cents).to eq(0)
        expect(result.invoice.prepaid_credit_amount_cents).to eq(12)

        expect(Credits::AppliedPrepaidCreditsService).to have_received(:call).with(
          invoice: result.invoice
        )
      end
    end

    context "when invoice total amount cents is zero" do
      before { create(:credit_note, customer:) }

      it "does not call apply prepaid credits service" do
        allow(Credits::AppliedPrepaidCreditsService).to receive(:call).and_call_original

        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.total_amount_cents).to eq(0)
        expect(result.invoice.prepaid_credit_amount_cents).to eq(0)

        expect(Credits::AppliedPrepaidCreditsService).not_to have_received(:call)
      end
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { invoice_service.call }
    end

    it_behaves_like "applies invoice_custom_sections from resource" do
      let(:service_call) { invoice_service.call }
      let(:resource_with_custom_section) { subscription }
      let(:applied_section_factory) { :subscription_applied_invoice_custom_section }
      let(:resource_association_key) { :subscription }
    end

    context "when an error occurs" do
      context "with a stale object error" do
        before do
          create(:wallet, customer:, balance_cents: 100)
        end

        it "propagates the error" do
          allow_any_instance_of(Credits::AppliedPrepaidCreditsService) # rubocop:disable RSpec/AnyInstance
            .to receive(:call).and_raise(ActiveRecord::StaleObjectError)

          expect { invoice_service.call }.to raise_error(ActiveRecord::StaleObjectError)
        end
      end

      context "with a failed to acquire lock error" do
        it "propagates the error" do
          allow_any_instance_of(Credits::AppliedPrepaidCreditsService) # rubocop:disable RSpec/AnyInstance
            .to receive(:call).and_raise(Customers::FailedToAcquireLock)

          expect { invoice_service.call }.to raise_error(Customers::FailedToAcquireLock)
        end
      end

      context "with a sequence error" do
        it "propagates the error" do
          allow_any_instance_of(Invoice) # rubocop:disable RSpec/AnyInstance
            .to receive(:save!).and_raise(Sequenced::SequenceError)

          expect { invoice_service.call }.to raise_error(Sequenced::SequenceError)
        end
      end
    end
  end
end
