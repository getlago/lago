# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Payloads::Factory do
  describe ".new_instance" do
    subject(:new_instance_call) { described_class.new_instance(integration_customer:, subscription:) }

    let(:subscription) { FactoryBot.create(:subscription) }

    context "when customer is a hubspot customer" do
      let(:integration_customer) { FactoryBot.create(:hubspot_customer) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Subscriptions::Payloads::Hubspot)
      end
    end

    context "when customer is an anrok customer" do
      let(:integration_customer) { FactoryBot.create(:anrok_customer) }

      it "raises NotImplemented" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end

    context "when customer is an netsuite customer" do
      let(:integration_customer) { FactoryBot.create(:netsuite_customer) }

      it "raises NotImplemented" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end

    context "when customer is an xero customer" do
      let(:integration_customer) { FactoryBot.create(:xero_customer) }

      it "raises NotImplemented" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end
  end
end
