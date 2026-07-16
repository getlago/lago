# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::SendRestletEndpointService do
  subject(:send_restlet_endpoint_service) { described_class.new(integration:) }

  let(:integration) { create(:netsuite_integration) }

  describe ".call" do
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:endpoint) { "https://api.nango.dev/connection/#{integration.connection_id}/metadata" }

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:post_with_response)

      integration.script_endpoint_url = "https://example.com"
      integration.save!
    end

    it "successfully sends restlet endpoint" do
      send_restlet_endpoint_service.call

      expect(LagoHttpClient::Client).to have_received(:new)
        .with(endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(lago_client).to have_received(:post_with_response) do |payload|
        expect(payload[:restletEndpoint]).to eq("https://example.com")
      end
    end
  end
end
