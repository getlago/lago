# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::CreateService do
  subject(:result) do
    described_class.call(
      organization_id: organization.id,
      webhook_source:,
      code:,
      payload:,
      signature:,
      event_type:
    )
  end

  let(:organization) { create :organization }
  let(:code) { "stripe_1" }
  let(:webhook_source) { "stripe" }
  let(:signature) { "signature" }
  let(:payload) { event.merge(code:).to_json }
  let(:event_type) { "payment_intent.successful" }
  let(:validation_payload_result) { BaseService::Result.new }

  let(:event) do
    JSON.parse(get_stripe_fixtures("webhooks/payment_intent_succeeded.json"))
  end

  before do
    allow(InboundWebhooks::ValidatePayloadService)
      .to receive(:call)
      .and_return(validation_payload_result)
  end

  it "creates an inbound webhook" do
    expect { result }.to change(InboundWebhook, :count).by(1)
  end

  it "returns a pending inbound webhook in the result" do
    expect(result.inbound_webhook).to be_a(InboundWebhook)
    expect(result.inbound_webhook).to be_pending
  end

  it "queues an InboundWebhook::ProcessJob job" do
    result

    expect(InboundWebhooks::ProcessJob)
      .to have_been_enqueued
      .with(inbound_webhook: result.inbound_webhook)
  end

  context "with record validation error" do
    let(:webhook_source) { nil }

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:source]).to eq(["value_is_mandatory"])
    end

    it "does not queue an InboundWebhook::ProcessJob job" do
      result

      expect(InboundWebhooks::ProcessJob).not_to have_been_enqueued
    end
  end

  context "when payload validation fails" do
    let(:validation_payload_result) do
      BaseService::Result.new.service_failure!(
        code: "webhook_error", message: "Invalid signature"
      )
    end

    it "returns an error" do
      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ServiceFailure)
      expect(result.error.message).to eq "webhook_error: Invalid signature"
    end
  end
end
