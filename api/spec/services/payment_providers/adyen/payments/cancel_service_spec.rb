# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Adyen::Payments::CancelService do
  subject(:result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment_provider) do
    create(:adyen_provider, organization:, api_key: "AQEx...test", merchant_account: "LagoTest")
  end
  let(:provider_customer) { create(:adyen_customer, customer:, payment_provider:) }
  let(:payment) do
    create(:payment, payable: invoice, payment_provider:, payment_provider_customer: provider_customer,
      organization:, customer:, provider_payment_id: "PSPREF123",
      payable_payment_status: :pending, status: "Authorised")
  end

  let(:adyen_client) { instance_double(Adyen::Client) }
  let(:checkout) { Adyen::Checkout.new(adyen_client, 70) }
  let(:modifications_api) { Adyen::ModificationsApi.new(adyen_client, 70) }

  before do
    stub_const("AdyenResponse", Data.define(:status, :response))

    allow(::Adyen::Client).to receive(:new).and_return(adyen_client)
    allow(adyen_client).to receive(:checkout).and_return(checkout)
    allow(checkout).to receive(:modifications_api).and_return(modifications_api)
  end

  context "when the cancel is accepted" do
    let(:cancel_response) do
      AdyenResponse.new(
        status: 200,
        response: {
          "paymentPspReference" => "PSPREF123",
          "pspReference" => "MOD_REF_456",
          "status" => "received",
          "merchantAccount" => "LagoTest"
        }
      )
    end

    before do
      allow(modifications_api).to receive(:cancel_authorised_payment_by_psp_reference)
        .and_return(cancel_response)
    end

    it "calls the Adyen modifications cancel endpoint with the psp reference and merchant account" do
      result

      expect(modifications_api).to have_received(:cancel_authorised_payment_by_psp_reference)
        .with({merchantAccount: "LagoTest"}, "PSPREF123", anything)
    end

    it "passes an idempotency key scoped to the payment id" do
      result

      expect(modifications_api).to have_received(:cancel_authorised_payment_by_psp_reference)
        .with(anything, anything, headers: {"Idempotency-Key" => "payment-#{payment.id}"})
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "leaves the payment record untouched (lifecycle transition belongs to the webhook)" do
      expect { result }.not_to change { payment.reload.attributes }
    end
  end

  context "when Adyen returns a 422 response (non-cancelable state)" do
    let(:error_response) do
      AdyenResponse.new(
        status: 422,
        response: {
          "errorType" => "validation",
          "message" => "Original pspReference required for this operation"
        }
      )
    end

    before do
      allow(modifications_api).to receive(:cancel_authorised_payment_by_psp_reference)
        .and_return(error_response)
    end

    it "returns a successful result without raising" do
      expect(result).to be_success
    end

    it "logs the non-cancelable state with status and message" do
      allow(Rails.logger).to receive(:info)

      result

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/Adyen.*not cancelable.*status=422.*Original pspReference/))
    end

    it "does not mutate the payment record" do
      expect { result }.not_to change { payment.reload.attributes }
    end
  end

  context "when Adyen returns a non-422 4xx response" do
    let(:error_response) do
      AdyenResponse.new(
        status: 401,
        response: {
          "errorType" => "security",
          "message" => "Invalid Merchant Account"
        }
      )
    end

    before do
      allow(modifications_api).to receive(:cancel_authorised_payment_by_psp_reference)
        .and_return(error_response)
    end

    it "propagates the error so the caller can retry or surface the failure" do
      expect { result }.to raise_error(::Adyen::AdyenError)
    end
  end

  context "when the gem raises Adyen::ValidationError" do
    before do
      allow(modifications_api).to receive(:cancel_authorised_payment_by_psp_reference)
        .and_raise(::Adyen::ValidationError.new("payment already cancelled", nil))
    end

    it "returns a successful result without raising" do
      expect(result).to be_success
    end

    it "logs the underlying error message" do
      allow(Rails.logger).to receive(:info)

      result

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/Adyen.*not cancelable.*already cancelled/))
    end
  end

  context "when the gem raises a connection error" do
    before do
      allow(modifications_api).to receive(:cancel_authorised_payment_by_psp_reference)
        .and_raise(Faraday::ConnectionFailed.new("boom"))
    end

    it "raises a payments connection error so the caller can retry" do
      expect { result }.to raise_error(Invoices::Payments::ConnectionError)
    end
  end
end
