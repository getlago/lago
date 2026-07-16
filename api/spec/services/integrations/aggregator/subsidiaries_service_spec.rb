# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::SubsidiariesService do
  subject(:subsidiaries_service) { described_class.new(integration:) }

  let(:integration) { create(:netsuite_integration) }

  describe ".call" do
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:subsidiaries_endpoint) { "https://api.nango.dev/v1/netsuite/subsidiaries" }
    let(:headers) do
      {
        "Connection-Id" => integration.connection_id,
        "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
        "Provider-Config-Key" => "netsuite-tba"
      }
    end

    let(:aggregator_response) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/subsidiaries_response.json")
      JSON.parse(File.read(path))
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(subsidiaries_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:get)
        .with(headers:)
        .and_return(aggregator_response)
    end

    it "successfully fetches subsidiaries" do
      result = subsidiaries_service.call

      expect(LagoHttpClient::Client).to have_received(:new).with(subsidiaries_endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(lago_client).to have_received(:get)
      expect(result.subsidiaries.count).to eq(4)
      expect(result.subsidiaries.first.external_id).to eq("1")
      expect(result.subsidiaries.first.external_name).to eq("Holo, Inc.")
    end
  end
end
