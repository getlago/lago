# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboundWebhooks::ProcessService do
  subject(:result) { described_class.call(inbound_webhook:) }

  let(:inbound_webhook) { create :inbound_webhook, source: webhook_source }
  let(:webhook_source) { "stripe" }
  let(:handle_incoming_webhook_service_result) { BaseService::Result.new }

  before do
    allow(PaymentProviders::Stripe::HandleIncomingWebhookService)
      .to receive(:call)
      .and_return(handle_incoming_webhook_service_result)
  end

  it "updateds inbound webhook status to processing" do
    allow(inbound_webhook).to receive(:processing!)

    result
    expect(inbound_webhook).to have_received(:processing!).once
  end

  context "when inbound webhook source is invalid" do
    let(:webhook_source) { "invalid_source" }

    it "flags inbound webhook as failed and raises an error" do
      expect { result }
        .to change(inbound_webhook, :status).to("failed")
        .and raise_error(
          NameError,
          "Invalid inbound webhook source: invalid_source"
        )
    end
  end

  context "when inbound webhook is within processing window" do
    let(:inbound_webhook) do
      create(
        :inbound_webhook,
        source: webhook_source,
        status: "processing",
        processing_at: 119.minutes.ago
      )
    end

    it "does not process the webhook" do
      expect(result).to be_success
      expect(PaymentProviders::Stripe::HandleIncomingWebhookService)
        .not_to have_received(:call)
    end
  end

  context "when inbound webhook is outside the processing window" do
    let(:inbound_webhook) do
      create(
        :inbound_webhook,
        source: webhook_source,
        status: "processing",
        processing_at: 121.minutes.ago
      )
    end

    it "processes the webhook as normal" do
      expect(result).to be_success
    end
  end

  context "when inbound webhook has failed" do
    let(:inbound_webhook) { create :inbound_webhook, source: webhook_source, status: }
    let(:status) { "failed" }

    it "does not process the webhook" do
      expect(result).to be_success
      expect(PaymentProviders::Stripe::HandleIncomingWebhookService)
        .not_to have_received(:call)
    end
  end

  context "when inbound webhook has been succeeded" do
    let(:inbound_webhook) { create :inbound_webhook, source: webhook_source, status: }
    let(:status) { "succeeded" }

    it "does not process the webhook" do
      expect(result).to be_success
      expect(PaymentProviders::Stripe::HandleIncomingWebhookService)
        .not_to have_received(:call)
    end
  end

  context "when webhook source is Stripe" do
    let(:webhook_source) { "stripe" }

    before do
      allow(PaymentProviders::Stripe::HandleIncomingWebhookService)
        .to receive(:call)
        .and_return(handle_incoming_webhook_service_result)
    end

    it "delegates the call to the Stripe webhook hanlder service" do
      expect(result).to be_success
      expect(PaymentProviders::Stripe::HandleIncomingWebhookService)
        .to have_received(:call)
        .with(inbound_webhook:)
    end

    it "updated inbound webhook status to succeeded" do
      expect { result }.to change(inbound_webhook, :status).to("succeeded")
    end

    context "when the stripe webhook handling fails" do
      before do
        handle_incoming_webhook_service_result.service_failure!(
          code: "error", message: "error message"
        )
      end

      it "returns the handler results" do
        expect(result).not_to be_success
        expect(result).to eq(handle_incoming_webhook_service_result)
      end

      it "updates inbound webhook status to failed" do
        expect { result }.to change(inbound_webhook, :status).to("failed")
      end
    end
  end
end
