# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::IntegrationCustomerSerializer do
  subject(:serializer) { described_class.new(integration_customer, root_name: "integration_customer") }

  let(:integration_customer) { create(:netsuite_customer) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["integration_customer"]).to include(
      "lago_id" => integration_customer.id,
      "external_customer_id" => integration_customer.external_customer_id,
      "type" => "netsuite",
      "sync_with_provider" => integration_customer.sync_with_provider,
      "subsidiary_id" => integration_customer.subsidiary_id
    )
  end

  describe "#type" do
    subject(:type_call) { serializer.__send__(:type) }

    let(:integration_customer) { create(:netsuite_customer) }

    context "when customer is a netsuite customer" do
      it "returns netsuite" do
        expect(subject).to eq("netsuite")
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { create(:anrok_customer) }

      it "returns anrok" do
        expect(subject).to eq("anrok")
      end
    end

    context "when customer is a xero customer" do
      let(:integration_customer) { create(:xero_customer) }

      it "returns xero" do
        expect(subject).to eq("xero")
      end
    end

    context "when customer is a hubspot customer" do
      let(:integration_customer) { create(:hubspot_customer) }

      it "returns hubspot" do
        expect(subject).to eq("hubspot")
      end
    end

    context "when customer is a salesforce customer" do
      let(:integration_customer) { create(:salesforce_customer) }

      it "returns salesforce" do
        expect(subject).to eq("salesforce")
      end
    end
  end
end
