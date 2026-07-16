# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::XeroService do
  let(:integration) { create(:xero_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }

  describe "#create" do
    subject(:service_call) { described_class.new(integration:, customer:, subsidiary_id: nil).create }

    let(:contact_id) { SecureRandom.uuid }
    let(:create_result) do
      result = BaseService::Result.new
      result.contact_id = contact_id
      result
    end

    before do
      allow(Integrations::Aggregator::Contacts::CreateService)
        .to receive(:call).and_return(create_result)
    end

    it "returns integration customer" do
      result = service_call

      expect(Integrations::Aggregator::Contacts::CreateService).to have_received(:call)
      expect(result).to be_success
      expect(result.integration_customer.external_customer_id).to eq(contact_id)
      expect(result.integration_customer.integration_id).to eq(integration.id)
      expect(result.integration_customer.customer_id).to eq(customer.id)
      expect(result.integration_customer.type).to eq("IntegrationCustomers::XeroCustomer")
    end

    it "creates integration customer" do
      expect { service_call }.to change(IntegrationCustomers::XeroCustomer, :count).by(1)
    end
  end
end
