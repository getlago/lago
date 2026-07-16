# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::MoneyhashService do
  subject(:moneyhash_service) { described_class.new(invoice) }

  let(:invoice) { create(:invoice, organization:, customer:, invoice_type: :subscription, payment_status: :pending) }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:, payment_provider: moneyhash_provider) }

  let(:intent_processed_json) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/intent.processed.json"))) }
  let(:provider_payment_id) { intent_processed_json.dig("data", "id") }

  let(:mh_provider_service) { PaymentProviders::MoneyhashService.new }

  let(:payment_url_response) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/checkout_url_response.json"))) }

  describe "#update_payment_status" do
    before do
      intent_processed_json["data"]["intent"]["custom_fields"]["lago_payable_id"] = invoice.id

      moneyhash_provider
      moneyhash_customer
    end

    it "creates a payment and updates the invoice payment status" do
      result = moneyhash_service.update_payment_status(
        organization_id: organization.id,
        provider_payment_id: intent_processed_json.dig("data", "intent_id"),
        status: "SUCCESSFUL",
        metadata: intent_processed_json.dig("data", "intent", "custom_fields")
      ).raise_if_error!

      expect(result).to be_success
      expect(result.payment.status).to eq("succeeded")
      expect(result.payment.provider_payment_id).to eq(intent_processed_json.dig("data", "intent_id"))
      expect(result.payment.payable_payment_status).to eq("succeeded")
      expect(result.invoice.payment_status).to eq("succeeded")
      expect(result.invoice.payment_attempts).to eq(1)
    end

    it "enqueues a SendWebhookJob for payment.succeeded" do
      expect do
        moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: intent_processed_json.dig("data", "intent_id"),
          status: "SUCCESSFUL",
          metadata: intent_processed_json.dig("data", "intent", "custom_fields")
        )
      end.to have_enqueued_job(SendWebhookJob).with("payment.succeeded", Payment)
    end

    context "when amount_cents kwarg is provided" do
      it "records the Payment with that amount, not the invoice total" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: intent_processed_json.dig("data", "intent_id"),
          status: "SUCCESSFUL",
          amount_cents: 4242,
          metadata: intent_processed_json.dig("data", "intent", "custom_fields")
        ).raise_if_error!

        expect(result.payment.amount_cents).to eq(4242)
      end
    end

    context "when amount_cents kwarg is not provided" do
      it "falls back to the invoice's total amount" do
        result = moneyhash_service.update_payment_status(
          organization_id: organization.id,
          provider_payment_id: intent_processed_json.dig("data", "intent_id"),
          status: "SUCCESSFUL",
          metadata: intent_processed_json.dig("data", "intent", "custom_fields")
        ).raise_if_error!

        expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
      end
    end
  end

  describe "#generate_payment_url" do
    let(:response) { instance_double(Net::HTTPOK) }
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "#{PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/" }
    let(:payment_intent) { create(:payment_intent) }

    before do
      allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
      allow(lago_client).to receive(:post_with_response).and_return(response)
      allow(response).to receive(:body).and_return(payment_url_response.to_json)

      moneyhash_provider
      moneyhash_customer
    end

    it "generates the payment url" do
      result = moneyhash_service.generate_payment_url(payment_intent)
      expect(result).to be_success
      expect(result.payment_url).to eq("#{payment_url_response.dig("data", "embed_url")}?lago_request=generate_payment_url")
    end
  end
end
