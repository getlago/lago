# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Hubspot::Contacts::DeployPropertiesService do
  subject(:deploy_properties_service) { described_class.new(integration:) }

  let(:integration) { create(:hubspot_integration) }

  describe ".call" do
    let(:http_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/hubspot/properties" }
    let(:response) { instance_double("Response", success?: true) }

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(http_client)
      allow(http_client).to receive(:post_with_response).and_return(response)

      integration.contacts_properties_version = nil
      integration.save!
    end

    it "successfully deploys contacts properties and updates the contacts_properties_version" do
      deploy_properties_service.call

      expect(LagoHttpClient::Client).to have_received(:new).with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(http_client).to have_received(:post_with_response) do |payload, headers|
        expect(payload[:objectType]).to eq("contacts")
        expect(headers["Authorization"]).to include("Bearer")
      end
      expect(integration.reload.contacts_properties_version).to eq(described_class::VERSION)
    end

    context "when contacts_properties_version is already up-to-date" do
      before do
        integration.contacts_properties_version = described_class::VERSION
        integration.save!
      end

      it "does not make an API call and keeps the version unchanged" do
        deploy_properties_service.call

        expect(LagoHttpClient::Client).not_to have_received(:new)
        expect(http_client).not_to have_received(:post_with_response)
        expect(integration.reload.contacts_properties_version).to eq(described_class::VERSION)
      end
    end

    context "when an HTTP error occurs" do
      let(:error) { LagoHttpClient::HttpError.new("error message", '{"error": {"message": "unknown failure"}}', nil) }

      before do
        allow(http_client).to receive(:post_with_response).and_raise(error)
      end

      it "delivers an integration error webhook" do
        expect { deploy_properties_service.call }.to enqueue_job(SendWebhookJob)
          .with(
            "integration.provider_error",
            integration,
            provider: "hubspot",
            provider_code: integration.code,
            provider_error: {
              message: "unknown failure",
              error_code: "integration_error"
            }
          )
      end
    end
  end
end
