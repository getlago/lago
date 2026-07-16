# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::AccountInformationService do
  subject(:service) { described_class.new(integration:) }

  let(:integration) { create(:hubspot_integration) }

  describe ".call" do
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/v1/account-information" }

    let(:headers) do
      {
        "Connection-Id" => integration.connection_id,
        "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
        "Provider-Config-Key" => "hubspot"
      }
    end

    let(:aggregator_response) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/account_information_response.json")
      JSON.parse(File.read(path))
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:get).with(headers:).and_return(aggregator_response)
    end

    it "successfully fetches account information" do
      result = service.call
      account_information = result.account_information

      expect(LagoHttpClient::Client).to have_received(:new).with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(lago_client).to have_received(:get)
      expect(account_information.id).to eq("1234567890")
    end

    it_behaves_like "throttles!", :hubspot
  end
end
