# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::Payments::CreateService do
  let(:organization) { create(:organization) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:, payment_provider: moneyhash_provider) }

  let(:reference) { "1234567890" }
  let(:metadata) { {} }

  let(:invoice) { create(:invoice, organization:, customer:, invoice_type: :subscription) }
  let(:payment) { create(:payment, payable: invoice, payment_provider: moneyhash_provider, payment_provider_customer: moneyhash_customer) }

  let(:failure_response) { JSON.parse(File.read("spec/fixtures/moneyhash/recurring_mit_payment_failure_response.json")) }
  let(:success_response) { JSON.parse(File.read("spec/fixtures/moneyhash/recurring_mit_payment_success_response.json")) }

  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:response) { instance_double(Net::HTTPOK) }
  let(:endpoint) { "#{PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/payments/intent/" }

  describe "#call" do
    before do
      allow(LagoHttpClient::Client).to receive(:new).with(endpoint).and_return(lago_client)
    end

    context "when payment succeeds" do
      before do
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(success_response.to_json)
      end

      it "returns success with payment details" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_success
        expect(result.payment).to have_attributes(
          status: "PROCESSED",
          provider_payment_id: success_response.dig("data", "id"),
          payable_payment_status: "succeeded"
        )
      end
    end

    context "when payment fails" do
      before do
        allow(lago_client).to receive(:post_with_response)
          .and_raise(LagoHttpClient::HttpError.new(400, failure_response, ""))
      end

      it "returns failure with error details" do
        result = described_class.call(payment:, reference:, metadata:)

        expect(result).to be_failure
        expect(result.error_code).to eq(400)
        expect(result.error_message).to eq(failure_response)
        expect(payment.status).to eq("PENDING")
        expect(payment.payable_payment_status).to eq("processing")
      end
    end

    context "when payment has a payment method" do
      let(:payment_method) do
        create(:payment_method,
          customer:,
          payment_provider_customer: moneyhash_customer,
          provider_method_id: "pm_test_123")
      end

      before do
        payment.update!(payment_method:)
        allow(lago_client).to receive(:post_with_response).and_return(response)
        allow(response).to receive(:body).and_return(success_response.to_json)
      end

      it "uses payment_method provider_method_id as card_token" do
        described_class.call(payment:, reference:, metadata:)

        expect(lago_client).to have_received(:post_with_response) do |params, _headers|
          expect(params[:card_token]).to eq("pm_test_123")
        end
      end
    end
  end
end
