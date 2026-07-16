# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCustomers::HubspotService do
  let(:integration) { create(:hubspot_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization:, customer_type: "individual") }
  let(:targeted_object) { "contacts" }

  describe "#create" do
    subject(:service_call) { described_class.new(integration:, customer:, subsidiary_id: nil, targeted_object:).create }

    let(:contact_id) { SecureRandom.uuid }
    let(:create_result) do
      result = BaseService::Result.new
      result.contact_id = contact_id
      result.email = customer.email
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
      expect(result.integration_customer.email).to eq(customer.email)
      expect(result.integration_customer.type).to eq("IntegrationCustomers::HubspotCustomer")
    end

    it "creates integration customer" do
      expect { service_call }.to change(IntegrationCustomers::HubspotCustomer, :count).by(1)
    end

    context "with targeted_object" do
      let(:customer) { create(:customer, organization:, customer_type:) }
      let(:customer_type) { "individual" }

      context 'when params[:targeted_object] is specified as "contacts"' do
        let(:targeted_object) { "contacts" }

        it "uses Integrations::Aggregator::Contacts::CreateService" do
          allow(Integrations::Aggregator::Contacts::CreateService).to receive(:call).and_return(create_result)
          service_call
          expect(Integrations::Aggregator::Contacts::CreateService).to have_received(:call)
        end
      end

      context 'when params[:targeted_object] is specified as "companies"' do
        let(:targeted_object) { "companies" }

        it "uses Integrations::Aggregator::Companies::CreateService" do
          allow(Integrations::Aggregator::Companies::CreateService).to receive(:call).and_return(create_result)
          service_call
          expect(Integrations::Aggregator::Companies::CreateService).to have_received(:call)
        end
      end

      context "when params[:targeted_object] is not specified and customer is an individual" do
        let(:targeted_object) { nil }
        let(:customer) { create(:customer, organization:, customer_type: "individual") }

        it "defaults to Integrations::Aggregator::Contacts::CreateService" do
          allow(Integrations::Aggregator::Contacts::CreateService).to receive(:call).and_return(create_result)
          service_call
          expect(Integrations::Aggregator::Contacts::CreateService).to have_received(:call)
        end
      end

      context "when params[:targeted_object] is not specified and customer is a company" do
        let(:targeted_object) { nil }
        let(:customer) { create(:customer, organization:, customer_type: "company") }

        it "defaults to Integrations::Aggregator::Companies::CreateService" do
          allow(Integrations::Aggregator::Companies::CreateService).to receive(:call).and_return(create_result)
          service_call
          expect(Integrations::Aggregator::Companies::CreateService).to have_received(:call)
        end
      end
    end
  end
end
