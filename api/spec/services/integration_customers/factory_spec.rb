# frozen_string_literal: true

# spec/factories/integration_customers/factory_spec.rb
require "rails_helper"

RSpec.describe IntegrationCustomers::Factory do
  describe ".new_instance" do
    subject { described_class.new_instance(integration:, customer:, subsidiary_id:, **params) }

    let(:organization) { membership.organization }
    let(:membership) { create(:membership) }
    let(:customer) { create(:customer, organization:) }
    let(:subsidiary_id) {}
    let(:params) { {} }

    context "when the integration is NetsuiteIntegration" do
      let(:integration) { create(:netsuite_integration, organization:) }

      it "returns an instance of IntegrationCustomers::NetsuiteService" do
        expect(subject).to be_an_instance_of(IntegrationCustomers::NetsuiteService)
      end
    end

    context "when the integration is AnrokIntegration" do
      let(:integration) { create(:anrok_integration, organization:) }

      it "returns an instance of IntegrationCustomers::AnrokService" do
        expect(subject).to be_an_instance_of(IntegrationCustomers::AnrokService)
      end
    end

    context "when the integration is XeroIntegration" do
      let(:integration) { create(:xero_integration, organization:) }

      it "returns an instance of IntegrationCustomers::XeroService" do
        expect(subject).to be_an_instance_of(IntegrationCustomers::XeroService)
      end
    end

    context "when the integration is HubspotIntegration" do
      let(:integration) { create(:hubspot_integration, organization:) }

      it "returns an instance of IntegrationCustomers::HubspotService" do
        expect(subject).to be_an_instance_of(IntegrationCustomers::HubspotService)
      end
    end

    context "when the integration is SalesforceIntegration" do
      let(:integration) { create(:salesforce_integration, organization:) }

      it "returns an instance of IntegrationCustomers::SalesforceService" do
        expect(subject).to be_an_instance_of(IntegrationCustomers::SalesforceService)
      end
    end

    context "when integration is nil" do
      let(:integration) { nil }

      it "raises a NotImplementedError" do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end
  end
end
