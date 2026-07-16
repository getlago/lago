# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::SalesforceService do
  let(:integration) { create(:salesforce_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:, customer_type: "individual") }

  describe "#create" do
    subject(:service_call) { described_class.new(integration:, customer:, subsidiary_id: nil).create }

    it "returns integration customer" do
      result = service_call

      expect(result).to be_success
      expect(result.integration_customer.integration_id).to eq(integration.id)
      expect(result.integration_customer.customer_id).to eq(customer.id)
      expect(result.integration_customer.type).to eq("IntegrationCustomers::SalesforceCustomer")
    end

    it "creates integration customer" do
      expect { service_call }.to change(IntegrationCustomers::SalesforceCustomer, :count).by(1)
    end
  end
end
