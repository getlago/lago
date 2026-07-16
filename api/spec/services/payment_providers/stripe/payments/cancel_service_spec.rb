# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Payments::CancelService do
  subject(:result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment_provider) { create(:stripe_provider, organization:, secret_key: "sk_test_123") }
  let(:payment) do
    create(:payment, payable: invoice, payment_provider:, organization:, customer:,
      provider_payment_id: "pi_test_123", payable_payment_status: :pending)
  end

  context "when the payment intent is cancelable" do
    before do
      stub_request(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .to_return(status: 200, body: {id: "pi_test_123", status: "canceled"}.to_json)
    end

    it "calls the Stripe cancel endpoint" do
      result

      expect(WebMock).to have_requested(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
    end

    it "uses the provider's secret key" do
      result

      expect(WebMock).to have_requested(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .with(headers: {"Authorization" => "Bearer sk_test_123"})
    end

    it "passes cancellation_reason: abandoned" do
      result

      expect(WebMock).to have_requested(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .with(body: hash_including("cancellation_reason" => "abandoned"))
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "writes the canceled status from the Stripe response onto the payment" do
      result

      expect(payment.reload.status).to eq("canceled")
    end

    it "maps the canceled status to a failed payable_payment_status" do
      result

      expect(payment.reload.payable_payment_status).to eq("failed")
    end
  end

  context "when the payment intent is no longer cancelable" do
    before do
      stub_request(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .to_return(
          status: 400,
          body: {error: {
            type: "invalid_request_error",
            code: "payment_intent_unexpected_state",
            message: "You cannot cancel this PaymentIntent because it has a status of succeeded."
          }}.to_json
        )
    end

    it "returns a successful result without raising" do
      expect(result).to be_success
    end

    it "logs the non-cancelable state" do
      allow(Rails.logger).to receive(:info)

      result

      expect(Rails.logger).to have_received(:info).with(a_string_matching(/Stripe.*not cancelable.*succeeded/))
    end

    it "does not mutate the payment record" do
      expect { result }.not_to change { payment.reload.attributes }
    end
  end

  context "when Stripe returns an InvalidRequestError with a different code" do
    before do
      stub_request(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .to_return(
          status: 400,
          body: {error: {
            type: "invalid_request_error",
            code: "parameter_invalid_empty",
            message: "Missing required param: amount."
          }}.to_json
        )
    end

    it "propagates the error so the caller can retry or surface the failure" do
      expect { result }.to raise_error(::Stripe::InvalidRequestError)
    end
  end

  context "when Stripe returns a different error" do
    before do
      stub_request(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
        .to_return(status: 401, body: {error: {type: "authentication_error", message: "Invalid API key."}}.to_json)
    end

    it "propagates the error so the caller can retry" do
      expect { result }.to raise_error(::Stripe::AuthenticationError)
    end
  end
end
