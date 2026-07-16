# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::HandleIncomingWebhookService do
  subject(:result) { described_class.call(inbound_webhook:) }

  let(:organization) { create(:organization) }
  let(:code) { "mh-test" }
  let(:moneyhash_provider) { create(:moneyhash_provider, code:, organization:) }
  let(:intent_processed_payload) { JSON.parse(Rails.root.join("spec/fixtures/moneyhash/intent.processed.json").read) }
  let(:inbound_webhook) { create :inbound_webhook, source: :moneyhash, organization:, code:, payload: intent_processed_payload }
  let(:event_result) { intent_processed_payload }

  it "checks the webhook" do
    moneyhash_provider
    expect(result).to be_success
    expect(result.event).to eq(event_result)
    expect(PaymentProviders::Moneyhash::HandleEventJob).to have_been_enqueued
  end

  context "when failing to find the provider" do
    let(:inbound_webhook) { create :inbound_webhook, source: :moneyhash, organization:, code:, payload: "invalid" }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.code).to eq("webhook_error")
      expect(result.error.error_message).to eq("Payment provider not found")
    end
  end
end
