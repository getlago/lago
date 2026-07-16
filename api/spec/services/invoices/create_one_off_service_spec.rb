# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::CreateOneOffService do
  let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:} }
  let(:timestamp) { Time.zone.now.beginning_of_month }
  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, billing_entity:, organization:, rate: 20) }
  let(:currency) { "EUR" }
  let(:add_on_first) { create(:add_on, organization:) }
  let(:add_on_second) { create(:add_on, amount_cents: 400, organization:) }
  let(:fees) do
    [
      {
        add_on_code: add_on_first.code,
        unit_amount_cents: 1200,
        units: 2,
        description: "desc-123"
      },
      {
        add_on_code: add_on_second.code
      }
    ]
  end

  describe "call" do
    before do
      tax

      allow(SegmentTrackJob).to receive(:perform_later)
      allow(Invoices::TransitionToFinalStatusService).to receive(:call).and_call_original
      CurrentContext.source = "api"
    end

    it "creates an invoice" do
      result = described_class.call(**args)

      expect(result).to be_success

      expect(result.invoice.issuing_date.to_date).to eq(timestamp)
      expect(result.invoice.invoice_type).to eq("one_off")
      expect(result.invoice.payment_status).to eq("pending")
      expect(result.invoice.fees.where(fee_type: :add_on).count).to eq(2)
      expect(result.invoice.fees.pluck(:description)).to contain_exactly("desc-123", add_on_second.description)

      expect(result.invoice.currency).to eq("EUR")
      expect(result.invoice.fees_amount_cents).to eq(2800)

      expect(result.invoice.taxes_amount_cents).to eq(560)
      expect(result.invoice.taxes_rate).to eq(20)
      expect(result.invoice.applied_taxes.count).to eq(1)

      expect(result.invoice.total_amount_cents).to eq(3360)
      expect(result.invoice.voided_invoice_id).to be_nil

      expect(result.invoice).to be_finalized
      expect(Invoices::TransitionToFinalStatusService).to have_received(:call).with(invoice: result.invoice)
      expect(result.invoice.applied_invoice_custom_sections.count).to eq(0)
    end

    context "when voided invoice id is passed" do
      let(:voided_invoice_id) { SecureRandom.uuid }
      let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, voided_invoice_id:} }

      it "creates an invoice" do
        result = described_class.call(**args)

        expect(result).to be_success
        expect(result.invoice.voided_invoice_id).to eq(voided_invoice_id)
      end
    end

    context "when purchase_order_number is passed" do
      let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, purchase_order_number: "PO-123"} }

      it "stamps the purchase order number on the invoice" do
        result = described_class.call(**args)

        expect(result).to be_success
        expect(result.invoice.purchase_order_number).to eq("PO-123")
      end
    end

    context "with custom sections" do
      let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }
      let(:args) do
        {
          customer:,
          timestamp: timestamp.to_i,
          fees:,
          currency:,
          invoice_custom_section:
        }
      end

      context "when custom section id is passed" do
        let(:invoice_custom_section) do
          {
            invoice_custom_section_codes: [section_1.code]
          }
        end

        it "creates the invoice correctly with sections" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice).to be_finalized
          expect(result.invoice.applied_invoice_custom_sections.pluck(:code)).to eq([section_1.code])
        end
      end

      context "when custom section needs to be skipped" do
        let(:invoice_custom_section) do
          {
            invoice_custom_section_codes: [section_1.code],
            skip_invoice_custom_sections: true
          }
        end

        it "creates the invoice correctly without sections" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice).to be_finalized
          expect(result.invoice.applied_invoice_custom_sections.count).to eq(0)
        end
      end
    end

    it_behaves_like "syncs invoice" do
      let(:service_call) { described_class.call(**args) }
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { described_class.call(**args) }
    end

    it "calls SegmentTrackJob" do
      invoice = described_class.call(**args).invoice

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

      described_class.call(**args)

      expect(Invoices::Payments::CreateService).to have_received(:call_async)
    end

    context "when skip_payment is true" do
      it "does not create a payment" do
        allow(Invoices::Payments::CreateService).to receive(:call_async)

        described_class.call(**args.merge(skip_psp: true))

        expect(Invoices::Payments::CreateService).not_to have_received(:call_async)
      end
    end

    it "enqueues a SendWebhookJob" do
      expect do
        described_class.call(**args)
      end.to have_enqueued_job(SendWebhookJob)
    end

    it "enqueues GenerateDocumentsJob with email false" do
      expect do
        described_class.call(**args)
      end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
    end

    context "when there is tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
      let(:response) { instance_double(Net::HTTPOK) }
      let(:lago_client) { instance_double(LagoHttpClient::Client) }
      let(:endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
      let(:body) do
        p = Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response_multiple_fees.json")
        json = File.read(p)

        # setting item_id based on the test example
        response = JSON.parse(json)
        response["succeededInvoices"].first["fees"].first["item_id"] = "fee_id_1"
        response["succeededInvoices"].first["fees"].first["tax_breakdown"].first["tax_amount"] = 240
        response["succeededInvoices"].first["fees"].last["item_id"] = "fee_id_2"
        response["succeededInvoices"].first["fees"].last["tax_breakdown"].first["tax_amount"] = 60

        response.to_json
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
        allow_any_instance_of(Fee).to receive(:id).and_wrap_original do |m, *args| # rubocop:disable RSpec/AnyInstance
          fee = m.receiver
          if fee.add_on_id == add_on_first.id
            "fee_id_1"
          elsif fee.add_on_id == add_on_second.id
            "fee_id_2"
          else
            m.call(*args)
          end
        end
      end

      it "creates a pending invoice for async tax resolution" do
        result = described_class.call(**args)

        expect(result).to be_success

        expect(result.invoice.issuing_date.to_date).to eq(timestamp)
        expect(result.invoice.invoice_type).to eq("one_off")
        expect(result.invoice.status).to eq("pending")
        expect(result.invoice.tax_status).to eq("pending")
        expect(result.invoice.fees.where(fee_type: :add_on).count).to eq(2)
        expect(result.invoice.fees.pluck(:description)).to contain_exactly("desc-123", add_on_second.description)

        expect(result.invoice.currency).to eq("EUR")
        expect(result.invoice.fees_amount_cents).to eq(2800) # 2400 + 400
      end

      it "does not produce an activity log" do
        result = described_class.call(**args)

        expect(Utils::ActivityLog).not_to have_produced("invoice.one_off_created").with(result.invoice)
      end

      context "with custom sections applied at the billing entity level" do
        let(:custom_section) { create(:invoice_custom_section, organization:) }

        before do
          create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: custom_section)
        end

        it "applies the custom sections even though tax resolution is deferred" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice.status).to eq("pending")
          expect(result.invoice.applied_invoice_custom_sections.pluck(:code)).to eq([custom_section.code])
        end
      end
    end

    context "when invoice amount in cents is zero" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 0,
            units: 2,
            description: "desc-123"
          }
        ]
      end

      it "creates a payment_succeeded invoice" do
        result = described_class.call(**args)

        expect(result).to be_success

        expect(result.invoice.issuing_date.to_date).to eq(timestamp)
        expect(result.invoice.invoice_type).to eq("one_off")
        expect(result.invoice.payment_status).to eq("succeeded")
        expect(result.invoice.fees.where(fee_type: :add_on).count).to eq(1)
        expect(result.invoice.fees.pluck(:description)).to contain_exactly("desc-123")

        expect(result.invoice.currency).to eq("EUR")
        expect(result.invoice.fees_amount_cents).to eq(0)
        expect(result.invoice.taxes_amount_cents).to eq(0)
        expect(result.invoice.taxes_rate).to eq(20)
        expect(result.invoice.total_amount_cents).to eq(0)

        expect(result.invoice).to be_finalized
      end
    end

    context "with lago_premium", :premium do
      it "enqueues GenerateDocumentsJob with email true" do
        expect do
          described_class.call(**args)
        end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
      end

      context "when organization does not have right email settings" do
        before { customer.billing_entity.update!(email_settings: []) }

        it "enqueues GenerateDocumentsJob with email false" do
          expect do
            described_class.call(**args)
          end.to have_enqueued_job(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
        end
      end
    end

    context "with customer timezone" do
      before { customer.update!(timezone: "America/Los_Angeles") }

      let(:timestamp) { DateTime.parse("2022-11-25 01:00:00") }

      it "assigns the issuing date in the customer timezone" do
        result = described_class.call(**args)

        expect(result.invoice.issuing_date.to_s).to eq("2022-11-24")
      end
    end

    context "when currency does not match" do
      let(:currency) { "NOK" }

      it "fails" do
        result = described_class.call(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:currency)
        expect(result.error.messages[:currency]).to include("currencies_does_not_match")
      end
    end

    context "when currency does not present" do
      let(:currency) { nil }

      before { customer.update!(currency: nil) }

      it "fails" do
        result = described_class.call(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:currency)
        expect(result.error.messages[:currency]).to include("value_is_mandatory")
      end
    end

    context "when customer is not found" do
      let(:customer) { nil }

      it "returns a not found error" do
        result = described_class.call(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when fees are blank" do
      let(:fees) { [] }

      it "returns a not found error" do
        result = described_class.call(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("fees_not_found")
      end
    end

    context "with invalid payment method" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:args) do
        {
          customer:,
          timestamp: timestamp.to_i,
          fees:,
          currency:,
          payment_method_params:
        }
      end

      before { payment_method }

      context "when type is invalid" do
        let(:payment_method_params) do
          {
            payment_method_id: payment_method.id,
            payment_method_type: "invalid"
          }
        end

        it "fails" do
          result = described_class.call(**args)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end

      context "when ID is invalid" do
        let(:payment_method_params) do
          {
            payment_method_id: "invalid",
            payment_method_type: "provider"
          }
        end

        it "fails" do
          result = described_class.call(**args)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end
    end

    context "when multi_entity_billing feature flag is enabled" do
      let(:other_billing_entity) { create(:billing_entity, organization:) }

      before do
        organization.enable_feature_flag!(:multi_entity_billing)
        create(:tax, :applied_to_billing_entity, billing_entity: other_billing_entity, organization:, rate: 20)
      end

      context "when billing_entity_id is provided" do
        let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, billing_entity_id: other_billing_entity.id} }

        it "stamps the invoice with the resolved billing entity" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice.billing_entity).to eq(other_billing_entity)
        end
      end

      context "when billing_entity_code is provided" do
        let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, billing_entity_code: other_billing_entity.code} }

        it "stamps the invoice with the resolved billing entity" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice.billing_entity).to eq(other_billing_entity)
        end
      end

      context "when neither billing_entity_id nor billing_entity_code is provided" do
        it "falls back to the customer's billing entity" do
          result = described_class.call(**args)

          expect(result).to be_success
          expect(result.invoice.billing_entity).to eq(customer.billing_entity)
        end
      end

      context "when billing_entity_id is unknown" do
        let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, billing_entity_id: SecureRandom.uuid} }

        it "returns a not found error" do
          result = described_class.call(**args)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("billing_entity_not_found")
        end
      end

      context "when billing_entity_code is unknown" do
        let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, billing_entity_code: "unknown_code"} }

        it "returns a not found error" do
          result = described_class.call(**args)

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("billing_entity_not_found")
        end
      end
    end

    context "when multi_entity_billing feature flag is disabled" do
      let(:other_billing_entity) { create(:billing_entity, organization:) }
      let(:args) { {customer:, timestamp: timestamp.to_i, fees:, currency:, billing_entity_id: other_billing_entity.id} }

      it "ignores the billing_entity param and falls back to the customer's billing entity" do
        result = described_class.call(**args)

        expect(result).to be_success
        expect(result.invoice.billing_entity).to eq(customer.billing_entity)
      end
    end

    context "when add_on_code is invalid" do
      let(:fees) do
        [
          {
            add_on_code: add_on_first.code,
            unit_amount_cents: 1200,
            units: 2,
            description: "desc-123"
          },
          {
            add_on_code: "invalid"
          }
        ]
      end

      it "returns a not found error" do
        result = described_class.call(**args)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("add_on_not_found")
      end
    end
  end
end
