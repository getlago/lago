# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::CustomObjectService do
  subject(:custom_object_service) { described_class.new(integration:, name:) }

  let(:integration) { create(:hubspot_integration) }
  let(:name) { "LagoInvoices" }

  describe ".call" do
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/hubspot/custom-object" }

    let(:headers) do
      {
        "Connection-Id" => integration.connection_id,
        "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
        "Provider-Config-Key" => "hubspot"
      }
    end

    let(:body) do
      {
        "name" => name
      }
    end

    let(:aggregator_response) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/custom_object_response.json")
      JSON.parse(File.read(path))
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:get).with(headers:, body:).and_return(aggregator_response)
    end

    it "successfully fetches custom object" do
      result = custom_object_service.call
      custom_object = result.custom_object

      expect(LagoHttpClient::Client).to have_received(:new).with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(lago_client).to have_received(:get)
      expect(custom_object.id).to eq("35482707")
      expect(custom_object.objectTypeId).to eq("2-35482707")
    end
  end
end
