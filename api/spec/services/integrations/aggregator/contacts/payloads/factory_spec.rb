# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Contacts::Payloads::Factory do
  let(:customer) { integration_customer.customer }
  let(:integration) { integration_customer.integration }
  let(:subsidiary_id) { "123" }

  describe ".new_instance" do
    subject(:new_instance_call) do
      described_class.new_instance(integration:, customer:, integration_customer:, subsidiary_id:)
    end

    context "when customer is a netsuite customer" do
      let(:integration_customer) { FactoryBot.create(:netsuite_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Contacts::Payloads::Netsuite)
      end
    end

    context "when customer is a xero customer" do
      let(:integration_customer) { FactoryBot.create(:xero_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Contacts::Payloads::Xero)
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { FactoryBot.create(:anrok_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Contacts::Payloads::Anrok)
      end
    end

    context "when customer is a hubspot customer" do
      let(:integration_customer) { FactoryBot.create(:hubspot_customer, customer:) }
      let(:customer) { FactoryBot.create(:customer, customer_type:) }
      let(:customer_type) { "individual" }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Contacts::Payloads::Hubspot)
      end
    end
  end

  describe "#create_body" do
    subject(:create_body) do
      described_class.new_instance(integration:, customer:, integration_customer:, subsidiary_id:).create_body
    end

    context "when customer is a netsuite customer" do
      let(:integration_customer) { FactoryBot.create(:netsuite_customer) }

      it "returns payload body" do
        expect(subject["columns"]["companyname"]).to eq(customer.name)
      end
    end

    context "when customer is a xero customer" do
      let(:integration_customer) { FactoryBot.create(:xero_customer) }

      it "returns payload body" do
        expect(subject.first["name"]).to eq(customer.name)
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { FactoryBot.create(:anrok_customer) }

      it "returns payload body" do
        expect(subject.first["name"]).to eq(customer.display_name(prefer_legal_name: false))
      end
    end
  end

  describe "#update_body" do
    subject(:update_body) do
      described_class.new_instance(integration:, customer:, integration_customer:, subsidiary_id:).update_body
    end

    context "when customer is a netsuite customer" do
      let(:integration_customer) { FactoryBot.create(:netsuite_customer) }

      it "returns payload body" do
        expect(subject["recordId"]).to eq(integration_customer.external_customer_id)
        expect(subject["columns"]["companyname"]).to eq(customer.name)
        expect(subject["columns"]["entityid"]).to eq(customer.external_id)
      end
    end

    context "when customer is a xero customer" do
      let(:integration_customer) { FactoryBot.create(:xero_customer) }

      it "returns payload body" do
        expect(subject.first["id"]).to eq(integration_customer.external_customer_id)
        expect(subject.first["name"]).to eq(customer.name)
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { FactoryBot.create(:anrok_customer) }

      it "returns payload body" do
        expect(subject.first["id"]).to eq(integration_customer.external_customer_id)
        expect(subject.first["name"]).to eq(customer.display_name(prefer_legal_name: false))
      end
    end
  end
end
