# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::HandleIncomingWebhookService do
  let(:webhook_service) { described_class.new(organization_id: organization.id, body:, signature:, code:) }

  let(:organization) { create(:organization) }
  let(:gocardless_provider) { create(:gocardless_provider, organization:) }

  let(:events) do
    path = Rails.root.join("spec/fixtures/gocardless/events.json")
    JSON.parse(File.read(path))
  end

  let(:body) { events.to_json }
  let(:events_result) { events["events"].map { |event| GoCardlessPro::Resources::Event.new(event) } }
  let(:signature) { "signature" }
  let(:code) { nil }

  before { gocardless_provider }

  describe "#call" do
    it "checks the webhook" do
      allow(GoCardlessPro::Webhook).to receive(:parse)
        .and_return(events_result)

      result = webhook_service.call
      expect(result).to be_success

      expect(result.events).to eq(events_result)
      expect(PaymentProviders::Gocardless::HandleEventJob).to have_been_enqueued
    end

    context "when failing to parse payload" do
      it "returns an error" do
        allow(GoCardlessPro::Webhook).to receive(:parse).and_raise(JSON::ParserError)

        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Invalid payload")
      end
    end

    context "when failing to validate the signature" do
      it "returns an error" do
        allow(GoCardlessPro::Webhook).to receive(:parse)
          .and_raise(GoCardlessPro::Webhook::InvalidSignatureError.new("error"))

        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Invalid signature")
      end
    end
  end
end
