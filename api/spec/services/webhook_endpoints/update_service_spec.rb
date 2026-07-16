# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEndpoints::UpdateService do
  subject(:update_service) { described_class.new(id: webhook_endpoint.id, organization:, params: update_params) }

  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let!(:webhook_endpoint) { create(:webhook_endpoint, organization:, name: "Original Webhook", event_types: ["customer.created"]) }
  let(:update_params) do
    {
      webhook_url: "http://foo.bar",
      signature_algo: "hmac",
      name: "Updated Webhook",
      event_types: ["customer.updated"]
    }
  end

  describe ".call" do
    it "updates the webhook endpoint" do
      result = update_service.call

      expect(result).to be_success
      expect(result.webhook_endpoint.webhook_url).to eq("http://foo.bar")
      expect(result.webhook_endpoint.signature_algo).to eq("hmac")
      expect(result.webhook_endpoint.name).to eq("Updated Webhook")
      expect(result.webhook_endpoint.event_types).to eq(["customer.updated"])
    end

    context "when updating with partial params" do
      let(:update_params) do
        {
          webhook_url: "http://foo.bar",
          signature_algo: "hmac"
        }
      end

      it "updates only the provided fields" do
        result = update_service.call

        expect(result).to be_success
        # updated fields
        expect(result.webhook_endpoint.webhook_url).to eq("http://foo.bar")
        expect(result.webhook_endpoint.signature_algo).to eq("hmac")
        # unchanged fields
        expect(result.webhook_endpoint.name).to eq("Original Webhook")
        expect(result.webhook_endpoint.event_types).to eq(["customer.created"])
      end
    end

    it_behaves_like "produces a security log", "webhook_endpoint.updated" do
      before { update_service.call }
    end

    context "when webhook endpoint does not exist" do
      let(:webhook_endpoint) { instance_double(WebhookEndpoint, id: "123456") }

      it "returns a not found error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.message).to eq("webhook_endpoint_not_found")
      end

      it_behaves_like "does not produce a security log" do
        before { update_service.call }
      end
    end

    context "when webhook url is invalid" do
      let(:update_params) do
        {
          webhook_url: "foobar"
        }
      end

      it "returns a validation failure" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.class).to eq(BaseService::ValidationFailure)
      end

      it_behaves_like "does not produce a security log" do
        before { update_service.call }
      end
    end

    context "when event types are invalid" do
      let(:update_params) do
        {
          event_types: ["invalid.event"]
        }
      end

      it "returns a validation failure" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.class).to eq(BaseService::ValidationFailure)
      end
    end

    context "when event_types is explicitly set to null" do
      let(:update_params) { {event_types: nil} }

      it "nullifies event_types" do
        result = update_service.call

        expect(result).to be_success
        expect(result.webhook_endpoint.event_types).to eq(nil)
      end
    end
  end
end
