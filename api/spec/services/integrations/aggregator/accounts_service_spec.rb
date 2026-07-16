# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::AccountsService do
  subject(:accounts_service) { described_class.new(integration:) }

  let(:integration) { create(:netsuite_integration) }

  describe ".call" do
    let(:lago_client) { instance_double(LagoHttpClient::Client) }
    let(:accounts_endpoint) { "https://api.nango.dev/v1/netsuite/accounts" }
    let(:params) { {limit: 450} }

    let(:headers) do
      {
        "Connection-Id" => integration.connection_id,
        "Authorization" => "Bearer #{ENV["NANGO_SECRET_KEY"]}",
        "Provider-Config-Key" => "netsuite-tba"
      }
    end

    let(:aggregator_response) do
      path = Rails.root.join("spec/fixtures/integration_aggregator/accounts_response.json")
      JSON.parse(File.read(path))
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(accounts_endpoint, retries_on: [OpenSSL::SSL::SSLError])
        .and_return(lago_client)
      allow(lago_client).to receive(:get)
        .with(headers:, params:)
        .and_return(aggregator_response)
    end

    it "successfully fetches accounts" do
      result = accounts_service.call
      account = result.accounts.first

      expect(LagoHttpClient::Client).to have_received(:new).with(accounts_endpoint, retries_on: [OpenSSL::SSL::SSLError])
      expect(lago_client).to have_received(:get)
      expect(result.accounts.count).to eq(3)
      expect(account.external_id).to eq("12ec4c59-ad56-4a4f-93eb-fb0a7740f4e2")
      expect(account.external_account_code).to eq("1111")
      expect(account.external_name).to eq("Accounts Payable")
    end
  end

  describe "#params" do
    subject(:method_call) { accounts_service.send(:params) }

    before { accounts_service.instance_variable_set(:@cursor, cursor) }

    context "when cursor is nil" do
      let(:cursor) { nil }
      let(:params) { {limit: described_class::LIMIT} }

      it "returns params without cursor" do
        expect(subject).to eq(params)
      end
    end

    context "when cursor is blank" do
      let(:cursor) { "" }
      let(:params) { {limit: described_class::LIMIT} }

      it "returns params without cursor" do
        expect(subject).to eq(params)
      end
    end

    context "when cursor is present" do
      let(:cursor) { "next_cursor_value" }
      let(:params) { {limit: described_class::LIMIT, cursor: "next_cursor_value"} }

      it "returns params with cursor" do
        expect(subject).to eq(params)
      end
    end
  end
end
