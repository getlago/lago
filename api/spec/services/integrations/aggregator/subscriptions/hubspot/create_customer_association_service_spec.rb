# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Hubspot::CreateCustomerAssociationService do
  subject(:service_call) { service.call }

  let(:service) { described_class.new(subscription:) }
  let(:integration) { create(:hubspot_integration, organization:, sync_subscriptions:) }
  let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }
  let(:endpoint) { "https://api.nango.dev/v1/hubspot/association" }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:, plan:) }

  let(:integration_subscription) do
    create(:integration_resource, resource_type: "subscription", syncable: subscription, integration:)
  end

  let(:headers) do
    {
      "Connection-Id" => integration.connection_id,
      "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
      "Provider-Config-Key" => "hubspot"
    }
  end

  let(:params) do
    service.__send__(:payload).customer_association_body
  end

  before do
    integration_customer
    integration_subscription

    allow(LagoHttpClient::Client).to receive(:new)
      .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      .and_return(lago_client)
    allow(lago_client).to receive(:put_with_response).with(params, headers)
  end

  describe "#call" do
    context "when integration.sync_subscriptions is false" do
      let(:sync_subscriptions) { false }

      it "returns result without making a request" do
        expect(service_call).to be_a(BaseService::Result)
      end
    end

    context "when integration.sync_subscriptions is true" do
      let(:sync_subscriptions) { true }

      context "when request is successful" do
        before do
          allow(service).to receive(:http_client).and_return(lago_client)
          allow(Integrations::Hubspot::Subscriptions::DeployObjectService).to receive(:call)
        end

        it "calls the DeployObjectService" do
          service_call
          expect(Integrations::Hubspot::Subscriptions::DeployObjectService).to have_received(:call).with(integration: integration)
        end

        it "returns result" do
          expect(service_call).to be_a(BaseService::Result)
        end

        it_behaves_like "throttles!", :hubspot
      end
    end
  end
end
