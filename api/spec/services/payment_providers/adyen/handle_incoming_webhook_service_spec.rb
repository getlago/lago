# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Adyen::HandleIncomingWebhookService do
  let(:webhook_service) { described_class.new(organization_id:, body:, code:) }

  let(:organization) { create(:organization) }
  let(:organization_id) { organization.id }
  let(:adyen_provider) { create(:adyen_provider, organization:, hmac_key: nil) }
  let(:code) { nil }

  let(:body) do
    JSON.parse(event_response_json)["notificationItems"].first&.dig("NotificationRequestItem")
  end

  let(:event_response_json) do
    path = Rails.root.join("spec/fixtures/adyen/webhook_authorisation_response.json")
    File.read(path)
  end

  before { adyen_provider }

  describe "#call" do
    it "checks the webhook" do
      result = webhook_service.call

      expect(result).to be_success

      expect(result.event).to eq(body)
      expect(PaymentProviders::Adyen::HandleEventJob).to have_been_enqueued
    end

    context "when organization does not exist" do
      let(:organization_id) { "123456789" }

      it "returns an error" do
        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Organization not found")
      end
    end

    context "when payment provider does not exist" do
      let(:adyen_provider) { nil }

      it "returns an error" do
        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Payment provider not found")
      end
    end

    context "when failing to validate the signature" do
      let(:adyen_provider) { create(:adyen_provider, organization:, hmac_key: "123") }

      it "returns an error" do
        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Invalid signature")
      end
    end

    context "when multiple payment providers exists and no code is provided" do
      before { create(:adyen_provider, organization:) }

      it "returns an error" do
        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Payment provider code is missing")
      end
    end
  end
end
