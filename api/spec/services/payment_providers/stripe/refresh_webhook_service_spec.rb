# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::RefreshWebhookService do
  subject(:provider_service) { described_class.new(payment_provider) }

  let(:organization) { create(:organization) }
  let(:payment_provider) { create(:stripe_provider, organization:, code: "stripe_sandbox", webhook_id: "we_1QzHw4Q8iJWBZFaMg54WCeIn") }

  describe ".call" do
    let(:url) { "#{ENV["LAGO_API_URL"]}/webhooks/stripe/#{organization.id}?code=stripe_sandbox" }
    let(:expected_request_body) do
      {
        enabled_events: PaymentProviders::StripeProvider::WEBHOOKS_EVENTS,
        url: url
      }
    end
    let(:stripe_api_response) do
      get_stripe_fixtures("webhook_endpoint_update_response.json") do |h|
        h["url"] = url
      end
    end

    before do
      stub_const("ENV", ENV.to_h.merge("LAGO_API_URL" => "https://billing.example.com"))
      stub_request(:post, "https://api.stripe.com/v1/webhook_endpoints/#{payment_provider.webhook_id}")
        .with(body: expected_request_body)
        .and_return(status: 200, body: stripe_api_response)
    end

    it "registers a webhook on stripe" do
      result = provider_service.call

      expect(result).to be_success
    end

    context "when authentication fails on stripe API" do
      before do
        allow(::Stripe::WebhookEndpoint)
          .to receive(:update)
          .and_raise(::Stripe::AuthenticationError.new(
            "This API call cannot be made with a publishable API key. Please use a secret API key. You can find a list of your API keys at https://dashboard.stripe.com/account/apikeys."
          ))
      end

      it "delivers an error webhook" do
        result = provider_service.call

        expect(result).to be_success

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "payment_provider.error",
            payment_provider,
            provider_error: {
              source: "stripe",
              action: "payment_provider.register_webhook",
              message: "This API call cannot be made with a publishable API key. Please use a secret API key. You can find a list of your API keys at https://dashboard.stripe.com/account/apikeys.",
              code: nil
            }
          )
      end
    end

    context "when the webhook limit is reached" do
      before do
        allow(::Stripe::WebhookEndpoint)
          .to receive(:update)
          .and_raise(::Stripe::InvalidRequestError.new(
            "You have reached the maximum of 16 test webhook endpoints.", {}
          ))
      end

      it "delivers an error webhook" do
        payment_provider.update!(secret_key: "sk_test_#{payment_provider.secret_key}")
        result = provider_service.call

        expect(result).to be_success

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "payment_provider.error",
            payment_provider,
            provider_error: {
              source: "stripe",
              action: "payment_provider.register_webhook",
              message: "You have reached the maximum of 16 test webhook endpoints.",
              code: nil
            }
          )
      end
    end
  end
end
