# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Subscriptions::Hubspot::BaseService do
  let(:service) { described_class.new(subscription:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:plan) { create(:plan, organization:) }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }

  describe "#initialize" do
    it "assigns the subscription" do
      expect(service.instance_variable_get(:@subscription)).to eq(subscription)
    end
  end

  describe "#integration_customer" do
    before do
      integration_customer
      create(:netsuite_customer, customer:)
    end

    it "returns the first hubspot kind integration customer" do
      expect(service.send(:integration_customer)).to eq(integration_customer)
    end

    it "memoizes the integration customer" do
      service.send(:integration_customer)
      expect(service.instance_variable_get(:@integration_customer)).to eq(integration_customer)
    end
  end
end
