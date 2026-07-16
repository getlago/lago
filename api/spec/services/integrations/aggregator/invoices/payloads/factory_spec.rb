# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Payloads::Factory do
  describe ".new_instance" do
    subject(:new_instance_call) { described_class.new_instance(integration_customer:, invoice:) }

    let(:invoice) { FactoryBot.create(:invoice) }

    context "when customer is a netsuite customer" do
      let(:integration_customer) { FactoryBot.create(:netsuite_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Invoices::Payloads::Netsuite)
      end
    end

    context "when customer is a xero customer" do
      let(:integration_customer) { FactoryBot.create(:xero_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Invoices::Payloads::Xero)
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { FactoryBot.create(:anrok_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Invoices::Payloads::Anrok)
      end
    end

    context "when customer is a hubspot customer" do
      let(:integration_customer) { FactoryBot.create(:hubspot_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Invoices::Payloads::Hubspot)
      end
    end
  end
end
