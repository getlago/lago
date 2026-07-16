# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::IntegrationCollectionMappingsResolver do
  let(:required_permission) { "organization:integrations:view" }
  let(:query) do
    <<~GQL
      query($integrationId: ID!) {
        integrationCollectionMappings(integrationId: $integrationId) {
          collection { id mappingType externalId taxCode currencies { currencyCode currencyExternalCode} }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:netsuite_collection_mapping) { create(:netsuite_collection_mapping, integration:) }

  before { netsuite_collection_mapping }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:view"

  it "returns a list of mappings" do
    result = execute_query(query:, variables: {integrationId: integration.id})

    integration_collection_mappings_response = result["data"]["integrationCollectionMappings"]

    mapping = integration_collection_mappings_response["collection"].sole
    expect(mapping["id"]).to eq(netsuite_collection_mapping.id)
    expect(mapping["mappingType"]).to eq(netsuite_collection_mapping.mapping_type)
    expect(mapping["externalId"]).to eq("netsuite-123")
    expect(mapping["taxCode"]).to eq("tax-code-1")
    expect(mapping["currencies"]).to be_nil

    expect(integration_collection_mappings_response["metadata"]["currentPage"]).to eq(1)
    expect(integration_collection_mappings_response["metadata"]["totalCount"]).to eq(1)
  end

  context "when a currency mapping" do
    let(:netsuite_collection_mapping) { create(:netsuite_currencies_mapping, integration:) }

    it do
      result = execute_query(query:, variables: {integrationId: integration.id})

      integration_collection_mappings_response = result["data"]["integrationCollectionMappings"]

      mapping = integration_collection_mappings_response["collection"].sole
      expect(mapping["id"]).to eq(netsuite_collection_mapping.id)
      expect(mapping["mappingType"]).to eq("currencies")
      expect(mapping["externalId"]).to be_nil
      expect(mapping["taxCode"]).to be_nil

      expect(mapping["currencies"]).to contain_exactly(
        {"currencyCode" => "EUR", "currencyExternalCode" => "3"},
        {"currencyCode" => "USD", "currencyExternalCode" => "7"}
      )
    end
  end

  context "when the integration id is not provided" do
    it "returns an error" do
      result = execute_query(query:)
      expect(result["errors"]).to eq([
        {
          "extensions" => {
            "problems" =>
             [
               {"explanation" => "Expected value to not be null", "path" => []}
             ],
            "value" => nil
          },
          "locations" => [{"column" => 7, "line" => 1}],
          "message" => "Variable $integrationId of type ID! was provided invalid value"
        }
      ])
    end
  end
end
