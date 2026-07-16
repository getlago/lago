# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::NetsuiteService do
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:) }
  let(:subsidiary_id) { "1" }

  describe "#create" do
    subject(:service_call) { described_class.new(subsidiary_id:, integration:, customer:).create }

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

    context "when integration customer does not exist" do
      it "returns integration customer" do
        result = service_call

        expect(Integrations::Aggregator::Contacts::CreateService).to have_received(:call)
        expect(result).to be_success
        expect(result.integration_customer.subsidiary_id).to eq("1")
        expect(result.integration_customer.external_customer_id).to eq(contact_id)
        expect(result.integration_customer.integration_id).to eq(integration.id)
        expect(result.integration_customer.customer_id).to eq(customer.id)
        expect(result.integration_customer.type).to eq("IntegrationCustomers::NetsuiteCustomer")
      end

      it "creates integration customer" do
        expect { service_call }.to change(IntegrationCustomers::NetsuiteCustomer, :count).by(1)
      end
    end

    context "when integration customer already exists" do
      let!(:existing_integration_customer) do
        create(:netsuite_customer, integration:, customer:, subsidiary_id:)
      end

      it "does not call aggregator contacts create service" do
        service_call
        expect(Integrations::Aggregator::Contacts::CreateService).not_to have_received(:call)
      end

      it "returns existing integration customer" do
        result = service_call

        expect(result).to be_success
        expect(result.integration_customer).to eq(existing_integration_customer)
        expect(IntegrationCustomers::NetsuiteCustomer.count).to eq(1)
      end
    end
  end
end
