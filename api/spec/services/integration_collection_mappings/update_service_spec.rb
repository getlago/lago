# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCollectionMappings::UpdateService do
  let(:integration_collection_mapping) { create(:netsuite_collection_mapping, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  describe "#call" do
    subject(:service_call) { described_class.call(integration_collection_mapping:, params: update_args) }

    before { integration_collection_mapping }

    let(:update_args) do
      {
        external_id: "456",
        external_name: "Name1",
        external_account_code: "code-2",
        tax_nexus: "updated-123",
        tax_code: "updated-456",
        tax_type: "updated-tax-type-1"
      }
    end

    context "without validation errors" do
      it "updates an integration collection mapping" do
        service_call

        integration_collection_mapping =
          IntegrationCollectionMappings::NetsuiteCollectionMapping.order(:updated_at).last

        expect(integration_collection_mapping.external_id).to eq("456")
        expect(integration_collection_mapping.external_name).to eq("Name1")
        expect(integration_collection_mapping.external_account_code).to eq("code-2")
        expect(integration_collection_mapping.tax_nexus).to eq(update_args[:tax_nexus])
        expect(integration_collection_mapping.tax_code).to eq(update_args[:tax_code])
        expect(integration_collection_mapping.tax_type).to eq(update_args[:tax_type])
      end

      it "returns an integration collection mapping in result object" do
        result = service_call

        expect(result.integration_collection_mapping).to be_a(IntegrationCollectionMappings::NetsuiteCollectionMapping)
      end
    end

    context "with netsuite currencies mapping" do
      let(:integration_collection_mapping) { create(:netsuite_currencies_mapping) }

      context "with valid currencies format" do
        it "saves the new mapping" do
          update_args[:currencies] = {"USD" => "799344"}
          result = service_call
          expect(result.integration_collection_mapping.reload.currencies).to eq({"USD" => "799344"})
        end
      end

      context "with invalid currencies format" do
        it "returns validation errors for invalid currencies format" do
          update_args[:currencies] = {yolo: true}
          result = service_call

          expect(result.error.messages[:currencies]).to eq ["invalid_format"]
        end
      end
    end
  end
end
