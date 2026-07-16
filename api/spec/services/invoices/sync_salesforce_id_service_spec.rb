# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::SyncSalesforceIdService do
  subject(:service_call) { sync_salesforce_id_service.call }

  let(:sync_salesforce_id_service) { described_class.new(invoice:, params:) }
  let(:organization) { create(:organization) }
  let(:invoice) { create(:invoice, organization:) }
  let(:params) { {} }

  describe "#call" do
    context "when the invoice is nil" do
      let(:invoice) { nil }

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when the integration is nil" do
      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("integration_not_found")
      end
    end

    context "when the integration resource does not exist" do
      let(:integration) { create(:salesforce_integration, organization:) }
      let(:params) do
        {
          integration_code: integration.code,
          external_id: "1234"
        }
      end

      it "creates a new integration resource" do
        expect { service_call }.to change(IntegrationResource, :count).by(1)

        result = service_call
        expect(result).to be_success
        expect(result.invoice).to eq(invoice)

        integration_resource = IntegrationResource.last
        expect(integration_resource.integration).to eq(integration)
        expect(integration_resource.external_id).to eq(params[:external_id])
        expect(integration_resource.syncable).to eq(invoice)
        expect(integration_resource.resource_type).to eq("invoice")
      end
    end
  end
end
