# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::MoneyhashService do
  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:) }

  describe "#create_or_update" do
    let(:webhook_signature_response) { JSON.parse(File.read(Rails.root.join("spec/fixtures/moneyhash/webhook_signature_response.json"))) }

    before do
      allow_any_instance_of(LagoHttpClient::Client).to receive(:get).and_return(webhook_signature_response) # rubocop:disable RSpec/AnyInstance
    end

    it "creates a new moneyhash provider with the webhook signature key" do
      result = described_class.new.create_or_update(organization:, code: "test_code", name: "test_name", flow_id: "test_flow_id")
      expect(result).to be_success
      expect(result.moneyhash_provider).to be_a(PaymentProviders::MoneyhashProvider)
      expect(result.moneyhash_provider.signature_key).to eq(webhook_signature_response.dig("data", "webhook_signature_secret"))
      expect(result.moneyhash_provider.code).to eq("test_code")
      expect(result.moneyhash_provider.name).to eq("test_name")
      expect(result.moneyhash_provider.flow_id).to eq("test_flow_id")
    end

    it_behaves_like "produces a security log", "integration.created" do
      before { described_class.new.create_or_update(organization:, code: "test_code", name: "test_name", flow_id: "test_flow_id") }
    end

    it "updates the existing moneyhash provider but leaves the signature key unchanged" do
      moneyhash_provider.update!(signature_key: "same_signature_key")
      result = described_class.new.create_or_update(organization:, code: moneyhash_provider.code, name: "updated_name", flow_id: "updated_flow_id")
      expect(result).to be_success
      expect(result.moneyhash_provider).to be_a(PaymentProviders::MoneyhashProvider)
      expect(result.moneyhash_provider.signature_key).to eq("same_signature_key")
      expect(result.moneyhash_provider.code).to eq(moneyhash_provider.code)
      expect(result.moneyhash_provider.name).to eq("updated_name")
      expect(result.moneyhash_provider.flow_id).to eq("updated_flow_id")
    end

    it_behaves_like "produces a security log", "integration.updated" do
      before do
        moneyhash_provider.update!(signature_key: "same_signature_key")
        described_class.new.create_or_update(organization:, code: moneyhash_provider.code, name: "updated_name", flow_id: "updated_flow_id")
      end
    end
  end
end
