# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEndpoints::CreateService do
  subject(:create_service) { described_class.new(organization:, params: create_params) }

  let(:organization) { create(:organization) }
  let(:create_params) do
    {
      webhook_url: "http://foo.bar",
      signature_algo: "hmac",
      name: "Test Webhook",
      event_types: ["customer.created"]
    }
  end

  describe ".call" do
    it "creates the webhook endpoint" do
      result = create_service.call

      aggregate_failures do
        expect(result).to be_success
        expect(result.webhook_endpoint.webhook_url).to eq("http://foo.bar")
        expect(result.webhook_endpoint.signature_algo).to eq("hmac")
        expect(result.webhook_endpoint.name).to eq("Test Webhook")
        expect(result.webhook_endpoint.event_types).to eq(["customer.created"])
      end
    end

    context "when creating with partial params" do
      let(:create_params) do
        {
          webhook_url: "http://foo.bar",
          signature_algo: "hmac"
        }
      end

      it "adds only the provided fields" do
        result = create_service.call

        aggregate_failures do
          expect(result).to be_success
          # added fields
          expect(result.webhook_endpoint.webhook_url).to eq("http://foo.bar")
          expect(result.webhook_endpoint.signature_algo).to eq("hmac")
          # default fields
          expect(result.webhook_endpoint.name).to be_nil
          expect(result.webhook_endpoint.event_types).to be_nil
        end
      end
    end

    context "when webhook url is invalid" do
      let(:create_params) do
        {
          webhook_url: "foobar"
        }
      end

      it "returns a validation failure" do
        result = create_service.call

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error.class).to eq(BaseService::ValidationFailure)
        end
      end
    end

    context "when event types are invalid" do
      let(:create_params) do
        {
          webhook_url: "http://foo.bar",
          event_types: ["invalid.event"]
        }
      end

      it "returns a validation failure" do
        result = create_service.call

        aggregate_failures do
          expect(result).not_to be_success
          expect(result.error.class).to eq(BaseService::ValidationFailure)
        end
      end
    end
  end
end
