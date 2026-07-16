# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Aggregator::Invoices::Hubspot::BaseService do
  let(:service) { described_class.new(invoice:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }

  describe "#initialize" do
    it "assigns the invoice" do
      expect(service.instance_variable_get(:@invoice)).to eq(invoice)
    end
  end

  describe "#integration_customer" do
    before do
      integration_customer
      create(:netsuite_customer, customer:)
    end

    it "returns the first Hubspot kind integration customer" do
      expect(service.send(:integration_customer)).to eq(integration_customer)
    end

    it "memoizes the integration customer" do
      service.send(:integration_customer)
      expect(service.instance_variable_get(:@integration_customer)).to eq(integration_customer)
    end
  end
end
