# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::ValidateIncomingWebhookService do
  subject(:result) do
    described_class.call(payload:, signature:, payment_provider:)
  end

  let(:payload) { "webhook_payload" }
  let(:signature) { "t=1743090080,v1=placeholder,v2=placeholder,v3=ca13480c8142f2f2b44822c764909027974e84b3e8c94457a314f129d8d60148" }
  let(:payment_provider) { create(:moneyhash_provider, signature_key: "test_signature_key") }

  it "return success when signature is valid" do
    result = described_class.call(payload:, signature:, payment_provider:)
    expect(result).to be_success
  end

  it "returns a service failure when signature is invalid" do
    signature = "Moneyhash-Signature: t=1743090080,v1=placeholder,v2=placeholder,v3=invalid_signature"
    result = described_class.call(payload:, signature:, payment_provider:)
    expect(result).not_to be_success
    expect(result.error).to be_a(BaseService::ServiceFailure)
    expect(result.error.message).to eq("webhook_error: Invalid signature")
  end
end
