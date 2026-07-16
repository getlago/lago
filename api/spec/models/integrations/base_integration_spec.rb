# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::BaseIntegration do
  subject(:integration) { described_class.new(attributes) }

  it_behaves_like "paper_trail traceable" do
    subject { build(:netsuite_integration) }
  end

  let(:secrets) { {"api_key" => api_key, "api_secret" => api_secret} }
  let(:api_key) { SecureRandom.uuid }
  let(:api_secret) { SecureRandom.uuid }

  let(:attributes) do
    {secrets: secrets.to_json}
  end

  it { is_expected.to have_many(:integration_mappings).dependent(:destroy) }
  it { is_expected.to have_many(:integration_collection_mappings).dependent(:destroy) }
  it { is_expected.to have_many(:integration_customers).dependent(:destroy) }
  it { is_expected.to have_many(:integration_items).dependent(:destroy) }
  it { is_expected.to have_many(:integration_resources).dependent(:destroy) }

  describe ".secrets_json" do
    it { expect(integration.secrets_json).to eq(secrets) }
  end

  describe ".push_to_secrets" do
    it "push the value into the secrets" do
      integration.push_to_secrets(key: "api_key", value: "foo_bar")

      expect(integration.secrets_json).to eq(
        {
          "api_key" => "foo_bar",
          "api_secret" => api_secret
        }
      )
    end
  end

  describe ".get_from_secrets" do
    it { expect(integration.get_from_secrets("api_secret")).to eq(api_secret) }

    it { expect(integration.get_from_secrets(nil)).to be_nil }
    it { expect(integration.get_from_secrets("foo")).to be_nil }
  end

  describe ".push_to_settings" do
    it "push the value into the secrets" do
      integration.push_to_settings(key: "key1", value: "val1")

      expect(integration.settings).to eq(
        {
          "key1" => "val1"
        }
      )
    end
  end

  describe ".get_from_settings" do
    before { integration.push_to_settings(key: "key1", value: "val1") }

    it { expect(integration.get_from_settings("key1")).to eq("val1") }

    it { expect(integration.get_from_settings(nil)).to be_nil }
    it { expect(integration.get_from_settings("foo")).to be_nil }
  end

  describe ".integration_type" do
    context "when type is netsuite" do
      it "returns the correct class name" do
        expect(described_class.integration_type("netsuite")).to eq("Integrations::NetsuiteIntegration")
      end
    end

    context "when type is okta" do
      it "returns the correct class name" do
        expect(described_class.integration_type("okta")).to eq("Integrations::OktaIntegration")
      end
    end

    context "when type is anrok" do
      it "returns the correct class name" do
        expect(described_class.integration_type("anrok")).to eq("Integrations::AnrokIntegration")
      end
    end

    context "when type is xero" do
      it "returns the correct class name" do
        expect(described_class.integration_type("xero")).to eq("Integrations::XeroIntegration")
      end
    end

    context "when type is hubspot" do
      it "returns the correct class name" do
        expect(described_class.integration_type("hubspot")).to eq("Integrations::HubspotIntegration")
      end
    end

    context "when type is salesforce" do
      it "returns the correct class name" do
        expect(described_class.integration_type("salesforce")).to eq("Integrations::SalesforceIntegration")
      end
    end

    context "when type is unknown" do
      it "raises a NotImplementedError" do
        expect { described_class.integration_type("unknown") }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#external_id_key" do
    it "returns id" do
      expect(integration.external_id_key).to eq("id")
    end
  end
end
