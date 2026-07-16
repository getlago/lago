# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::AnrokService do
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }

  describe "#create" do
    subject(:service_call) { described_class.new(subsidiary_id: nil, integration:, customer:).create }

    it "returns integration customer" do
      result = service_call

      expect(result).to be_success
      expect(result.integration_customer.external_customer_id).to eq(nil)
      expect(result.integration_customer.integration_id).to eq(integration.id)
      expect(result.integration_customer.customer_id).to eq(customer.id)
      expect(result.integration_customer.type).to eq("IntegrationCustomers::AnrokCustomer")
    end

    it "creates integration customer" do
      expect { service_call }.to change(IntegrationCustomers::AnrokCustomer, :count).by(1)
    end
  end
end
