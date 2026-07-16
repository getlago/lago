# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Companies::Payloads::Factory do
  let(:customer) { integration_customer.customer }
  let(:integration) { integration_customer.integration }
  let(:subsidiary_id) { "123" }

  describe ".new_instance" do
    subject(:new_instance_call) do
      described_class.new_instance(integration:, customer:, integration_customer:, subsidiary_id:)
    end

    context "when customer is a hubspot customer" do
      let(:integration_customer) { FactoryBot.create(:hubspot_customer, customer:) }
      let(:customer) { FactoryBot.create(:customer) }
      let(:customer_type) { ["company", nil].sample }

      it "returns payload" do
        expect(subject).to be_a(Integrations::Aggregator::Companies::Payloads::Hubspot)
      end
    end
  end
end
