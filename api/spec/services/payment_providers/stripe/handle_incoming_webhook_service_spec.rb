# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::HandleIncomingWebhookService do
  subject(:result) { described_class.call(inbound_webhook:) }

  let(:inbound_webhook) { create :inbound_webhook }
  let(:webhook_payload) { JSON.parse(inbound_webhook.payload) }
  let(:event_result) { Stripe::Event.construct_from(webhook_payload) }

  it "checks the webhook" do
    expect(result).to be_success
    expect(result.event).to eq(event_result)
    expect(PaymentProviders::Stripe::HandleEventJob).to have_been_enqueued
  end

  context "when failing to parse payload" do
    let(:inbound_webhook) { create :inbound_webhook, payload: "invalid" }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.code).to eq("webhook_error")
      expect(result.error.error_message).to eq("Invalid payload")
    end
  end
end
