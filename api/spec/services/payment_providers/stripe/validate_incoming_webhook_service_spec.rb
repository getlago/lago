# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::ValidateIncomingWebhookService do
  subject(:result) do
    described_class.call(payload:, signature:, payment_provider:)
  end

  let(:payload) { "webhook_payload" }
  let(:signature) { "signature" }
  let(:payment_provider) { create(:stripe_provider, webhook_secret:) }
  let(:webhook_secret) { "webhook_secret" }
  let(:stripe_default_tolerance) { 300 }

  before do
    allow(::Stripe::Webhook::Signature).to receive(:verify_header).and_return(true)
  end

  it "validates the payload" do
    expect(result).to be_success

    expect(::Stripe::Webhook::Signature)
      .to have_received(:verify_header)
      .with(
        payload,
        signature,
        webhook_secret,
        tolerance: stripe_default_tolerance
      ).once
  end

  context "when signature is invalid" do
    before do
      allow(::Stripe::Webhook::Signature)
        .to receive(:verify_header)
        .and_raise(
          ::Stripe::SignatureVerificationError.new(
            "Unable to extract timestamp and signatures from header",
            signature,
            http_body: payload
          )
        )
    end

    it "returns a service failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.message).to eq("webhook_error: Invalid signature")
    end
  end
end
