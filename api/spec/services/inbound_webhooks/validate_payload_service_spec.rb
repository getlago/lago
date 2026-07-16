# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::ValidatePayloadService do
  subject(:result) do
    described_class.call(
      organization_id: organization.id,
      code:,
      payload:,
      webhook_source:,
      signature:
    )
  end

  let(:organization) { create(:organization) }
  let(:code) { "payment_provider_1" }
  let(:payload) { "webhook_payload" }
  let(:signature) { "signature" }
  let(:webhook_source) { "stripe" }

  context "when webhook source is unknown" do
    let(:webhook_source) { "unknown" }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.message).to eq("webhook_error: Invalid webhook source")
    end
  end

  context "when payment provider is not found" do
    it "returns a service failure" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.message).to eq("payment_provider_not_found: Payment provider not found")
    end
  end

  context "when webhook source is stripe" do
    let(:webhook_source) { "stripe" }
    let(:payload) { "webhook_payload" }

    before do
      allow(::Stripe::Webhook::Signature).to receive(:verify_header).and_return(true)
      create(:stripe_provider, organization:, code:)
    end

    it "validates the payload" do
      expect(result).to be_success
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
end
