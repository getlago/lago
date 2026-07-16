# frozen_string_literal: true

require "rails_helper"

RSpec.describe IntegrationMappings::CreateService do
  let(:service) { described_class.new(membership.user) }

  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:add_on) { create(:add_on, organization:) }

  describe "#call" do
    subject(:service_call) { service.call(**create_args) }

    let(:create_args) do
      {
        mappable_type: "AddOn",
        mappable_id: add_on.id,
        integration_id: integration.id,
        external_id: "external_123"
      }
    end

    context "without validation errors" do
      it "creates an integration" do
        expect { service_call }.to change(IntegrationMappings::NetsuiteMapping, :count).by(1)

        integration_mapping = IntegrationMappings::NetsuiteMapping.order(:created_at).last

        expect(integration_mapping.mappable_type).to eq("AddOn")
        expect(integration_mapping.mappable_id).to eq(add_on.id)
        expect(integration_mapping.integration_id).to eq(integration.id)
      end

      it "returns an integration mapping in result object" do
        result = service_call

        expect(result.integration_mapping).to be_a(IntegrationMappings::NetsuiteMapping)
      end

      context "with billing entity" do
        let(:billing_entity) { create(:billing_entity, organization:) }
        let(:create_args) do
          {
            mappable_type: "AddOn",
            mappable_id: add_on.id,
            integration_id: integration.id,
            billing_entity_id: billing_entity.id,
            external_id: "external_123"
          }
        end

        it "creates an integration mapping with billing entity" do
          expect { service_call }.to change(IntegrationMappings::NetsuiteMapping, :count).by(1)

          integration_mapping = IntegrationMappings::NetsuiteMapping.order(:created_at).last

          expect(integration_mapping.mappable_type).to eq("AddOn")
          expect(integration_mapping.mappable_id).to eq(add_on.id)
          expect(integration_mapping.integration_id).to eq(integration.id)
          expect(integration_mapping.billing_entity_id).to eq(billing_entity.id)
          expect(integration_mapping.external_id).to eq("external_123")
        end

        context "when billing entity belongs to different organization" do
          let(:billing_entity) { create(:billing_entity, organization: create(:organization)) }

          it "returns an error" do
            expect(service_call).not_to be_success
            expect(service_call.error).to be_a(BaseService::NotFoundFailure)
            expect(service_call.error.message).to eq("billing_entity_not_found")
          end
        end
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
  end
end
