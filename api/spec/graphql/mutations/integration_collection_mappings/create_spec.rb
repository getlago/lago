# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationCollectionMappings::Create do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:mapping_type) { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit].sample.to_s }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:external_account_code) { Faker::Barcode.ean }
  let(:external_id) { SecureRandom.uuid }
  let(:external_name) { Faker::Commerce.department }

  let(:query) do
    <<-GQL
      mutation($input: CreateIntegrationCollectionMappingInput!) {
        createIntegrationCollectionMapping(input: $input) {
          id,
          integrationId,
          mappingType,
          externalAccountCode,
          externalId,
          externalName,
          currencies {currencyCode currencyExternalCode}
        }
      }
    GQL
  end
  let(:input) do
    {
      integrationId: integration.id,
      mappingType: mapping_type,
      externalAccountCode: external_account_code,
      externalId: external_id,
      externalName: external_name,
      **(billing_entity_id ? {billingEntityId: billing_entity_id} : {})
    }
  end
  let(:billing_entity_id) { nil }

  def create_integration_collection_mapping(input:, raw: false)
    result = execute_query(query:, input:)
    raw ? result : result["data"]["createIntegrationCollectionMapping"]
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "creates an integration collection mapping" do
    result = create_integration_collection_mapping(input:)

    expect(result).to match(
      "id" => be_present,
      "integrationId" => integration.id,
      "mappingType" => mapping_type,
      "externalAccountCode" => external_account_code,
      "externalId" => external_id,
      "externalName" => external_name,
      "currencies" => nil
    )
  end

  context "with currencies" do
    let(:input) do
      {
        integrationId: integration.id,
        mappingType: "currencies",
        currencies: [
          {"currencyCode" => "EUR", "currencyExternalCode" => "1000222"}
        ]
      }
    end

    it "updates the mapping" do
      result_data = subject["data"]["createIntegrationCollectionMapping"]
      expect(result_data["integrationId"]).to eq(integration.id)
      expect(result_data["currencies"]).to eq([{"currencyCode" => "EUR", "currencyExternalCode" => "1000222"}])
    end
  end

  context "with billing entity" do
    let(:billing_entity) { create(:billing_entity, organization:) }
    let(:billing_entity_id) { billing_entity.id }

    it "creates an integration collection mapping with billing entity" do
      result = create_integration_collection_mapping(input:)

      expect(result).to match(
        "id" => be_present,
        "integrationId" => integration.id,
        "mappingType" => mapping_type,
        "externalAccountCode" => external_account_code,
        "externalId" => external_id,
        "externalName" => external_name,
        "currencies" => nil
      )
    end

    context "when billing entity belongs to different organization" do
      let(:billing_entity) { create(:billing_entity, organization: create(:organization)) }

      it "returns an error when billing entity belongs to different organization" do
        result = create_integration_collection_mapping(input:, raw: true)

        expect_graphql_error(result:, message: "Resource not found")
      end
    end
  end
end
