# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationMappings::Create do
  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:mappable) { create(:add_on, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:external_account_code) { Faker::Barcode.ean }
  let(:external_id) { SecureRandom.uuid }
  let(:external_name) { Faker::Commerce.department }
  let(:mutation) do
    <<-GQL
      mutation($input: CreateIntegrationMappingInput!) {
        createIntegrationMapping(input: $input) {
          id,
          integrationId,
          mappableId,
          mappableType,
          billingEntityId,
          externalAccountCode,
          externalId,
          externalName
        }
      }
    GQL
  end
  let(:input) do
    {
      integrationId: integration.id,
      mappableId: mappable.id,
      mappableType: "AddOn",
      externalAccountCode: external_account_code,
      externalId: external_id,
      externalName: external_name,
      **(billing_entity_id ? {billingEntityId: billing_entity_id} : {})
    }
  end
  let(:billing_entity_id) { nil }

  def create_integration_mapping(input:, raw: false)
    result = execute_query(query: mutation, input:)
    raw ? result : result["data"]["createIntegrationMapping"]
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "creates an integration mapping" do
    result = create_integration_mapping(input:)

    expect(result).to match(
      "id" => be_present,
      "integrationId" => integration.id,
      "mappableId" => mappable.id,
      "mappableType" => "AddOn",
      "billingEntityId" => nil,
      "externalAccountCode" => external_account_code,
      "externalId" => external_id,
      "externalName" => external_name
    )
  end

  context "with billing entity" do
    let(:billing_entity) { create(:billing_entity, organization: organization) }
    let(:billing_entity_id) { billing_entity.id }

    it "creates an integration mapping with billing entity" do
      result = create_integration_mapping(input:)

      expect(result).to match(
        "id" => be_present,
        "integrationId" => integration.id,
        "mappableId" => mappable.id,
        "mappableType" => "AddOn",
        "billingEntityId" => billing_entity.id,
        "externalAccountCode" => external_account_code,
        "externalId" => external_id,
        "externalName" => external_name
      )
    end

    context "when billing entity belongs to different organization" do
      let(:billing_entity) { create(:billing_entity, organization: create(:organization)) }

      it "returns an error when billing entity belongs to different organization" do
        result = create_integration_mapping(input:, raw: true)

        expect_graphql_error(result:, message: "Resource not found")
      end
    end
  end
end
