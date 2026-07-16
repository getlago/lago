# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Payments::Payloads::Factory do
  describe ".new_instance" do
    subject(:new_instance_call) { described_class.new_instance(integration:, payment:) }

    let(:payment) { FactoryBot.create(:payment) }

    context "when integration is a netsuite integration" do
      let(:integration) { FactoryBot.create(:netsuite_integration) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Payments::Payloads::Netsuite)
      end
    end

    context "when integration is a xero integration" do
      let(:integration) { FactoryBot.create(:xero_integration) }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Payments::Payloads::Xero)
      end
    end

    context "when integration is an anrok integration" do
      let(:integration) { FactoryBot.create(:anrok_integration) }

      it "raises NotImplemented" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end
  end
end
