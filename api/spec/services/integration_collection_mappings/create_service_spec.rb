# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationCollectionMappings::CreateService do
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:add_on) { create(:add_on, organization:) }

  describe "#call" do
    subject(:service_call) { described_class.call(params: create_args) }

    let(:create_args) do
      {
        mapping_type: :fallback_item,
        integration_id: integration.id,
        tax_nexus: "123",
        tax_code: "456",
        tax_type: "tax-type-1"
      }
    end

    context "without validation errors" do
      it "creates an integration" do
        expect { service_call }.to change(IntegrationCollectionMappings::NetsuiteCollectionMapping, :count).by(1)

        integration_collection_mapping =
          IntegrationCollectionMappings::NetsuiteCollectionMapping.order(:created_at).last

        expect(integration_collection_mapping.organization).to eq(organization)
        expect(integration_collection_mapping.mapping_type).to eq("fallback_item")
        expect(integration_collection_mapping.integration_id).to eq(integration.id)
        expect(integration_collection_mapping.tax_nexus).to eq(create_args[:tax_nexus])
        expect(integration_collection_mapping.tax_code).to eq(create_args[:tax_code])
        expect(integration_collection_mapping.tax_type).to eq(create_args[:tax_type])
      end

      it "returns an integration collection mapping in result object" do
        result = service_call

        expect(result.integration_collection_mapping).to be_a(IntegrationCollectionMappings::NetsuiteCollectionMapping)
      end
    end

    context "with billing entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:create_args) do
        {
          mapping_type: :fallback_item,
          integration_id: integration.id,
          billing_entity_id: billing_entity.id,
          tax_nexus: "123",
          tax_code: "456",
          tax_type: "tax-type-1"
        }
      end

      it "creates an integration collection mapping with billing entity" do
        expect { service_call }.to change(IntegrationCollectionMappings::NetsuiteCollectionMapping, :count).by(1)

        integration_collection_mapping =
          IntegrationCollectionMappings::NetsuiteCollectionMapping.order(:created_at).last

        expect(integration_collection_mapping.billing_entity).to eq(billing_entity)
      end
    end

    context "with invalid billing entity" do
      let(:other_organization) { create(:organization) }
      let(:billing_entity) { create(:billing_entity, organization: other_organization) }
      let(:create_args) do
        {
          mapping_type: :fallback_item,
          integration_id: integration.id,
          billing_entity_id: billing_entity.id
        }
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("billing_entity_not_found")
      end
    end

    context "with non-existent billing entity" do
      let(:create_args) do
        {
          mapping_type: :fallback_item,
          integration_id: integration.id,
          billing_entity_id: "non-existent-id"
        }
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("billing_entity_not_found")
      end
    end

    context "with validation error" do
      let(:create_args) do
        {
          mappable_type: "AddOn",
          mappable_id: add_on.id
        }
      end

      it "returns an error" do
        result = service_call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("integration_not_found")
      end
    end

    context "with invalid currencies format" do
      let(:create_args) do
        {
          mapping_type: :currencies,
          integration_id: integration.id,
          currencies: {yolo: true}
        }
      end

      it "returns validation errors for invalid currencies format" do
        result = service_call

        expect(result.error.messages[:currencies]).to eq ["invalid_format"]
      end
    end
  end
end
