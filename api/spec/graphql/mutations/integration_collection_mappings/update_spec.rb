# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationCollectionMappings::Update do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "organization:integrations:update" }
  let(:integration_collection_mapping) { create(:netsuite_collection_mapping, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:mapping_type) { %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit].sample.to_s }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:external_account_code) { Faker::Barcode.ean }
  let(:external_id) { SecureRandom.uuid }
  let(:external_name) { Faker::Commerce.department }

  let(:query) do
    <<-GQL
      mutation($input: UpdateIntegrationCollectionMappingInput!) {
        updateIntegrationCollectionMapping(input: $input) {
          id,
          integrationId,
          mappingType,
          externalAccountCode,
          externalId,
          externalName
          currencies {currencyCode currencyExternalCode}
        }
      }
    GQL
  end

  let(:input) do
    original_mapping_type = integration_collection_mapping.mapping_type
    different_integration = create(:netsuite_integration, organization:)
    different_mapping_type = %i[fallback_item coupon subscription_fee minimum_commitment tax prepaid_credit].reject { |type| type.to_s == original_mapping_type }.sample.to_s

    {
      id: integration_collection_mapping.id,
      integrationId: different_integration.id,
      mappingType: different_mapping_type,
      externalAccountCode: external_account_code,
      externalId: external_id,
      externalName: external_name
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "updates a netsuite integration" do
    original_integration_id = integration_collection_mapping.integration_id
    original_mapping_type = integration_collection_mapping.mapping_type

    result = subject

    result_data = result["data"]["updateIntegrationCollectionMapping"]

    # Deprecated fields should be ignored - original values should remain
    expect(result_data["integrationId"]).to eq(original_integration_id)
    expect(result_data["mappingType"]).to eq(original_mapping_type)
    # Other fields should be updated normally
    expect(result_data["externalAccountCode"]).to eq(external_account_code)
    expect(result_data["externalId"]).to eq(external_id)
    expect(result_data["externalName"]).to eq(external_name)
  end

  context "when currencies" do
    let(:integration_collection_mapping) { create(:netsuite_currencies_mapping, integration:) }

    let(:input) do
      {
        id: integration_collection_mapping.id,
        currencies:
      }
    end

    context "when currency_code is duplicated" do
      let(:currencies) do
        [
          {currencyCode: "EUR", currencyExternalCode: "1"},
          {currencyCode: "EUR", currencyExternalCode: "2"},
          {currencyCode: "GBP", currencyExternalCode: "3"},
          {currencyCode: "USD", currencyExternalCode: "4"},
          {currencyCode: "USD", currencyExternalCode: "4"}
        ]
      end

      it "returns a graphql error" do
        result = subject

        expect_graphql_error(result:, message: "duplicated_field")
      end
    end

    context "when currencies is empty" do
      let(:currencies) { [] }

      it "returns a graphql error" do
        result = subject

        expect_unprocessable_entity(result, details: {
          currencies: ["cannot_be_empty"]
        })
      end
    end

    context "when currencies mapping has an empty value" do
      let(:currencies) do
        [
          {currencyCode: "EUR", currencyExternalCode: "1"},
          {currencyCode: "USD", currencyExternalCode: ""}
        ]
      end

      it "returns a graphql error" do
        result = subject

        expect_unprocessable_entity(result, details: {
          currencies: ["invalid_format"]
        })
      end
    end

    context "when mapping is valid" do
      let(:currencies) do
        [
          {"currencyCode" => "EUR", "currencyExternalCode" => "1000222"}
        ]
      end

      it "updates the mapping" do
        result_data = subject["data"]["updateIntegrationCollectionMapping"]
        expect(result_data["id"]).to eq(integration_collection_mapping.id)
        expect(result_data["currencies"]).to eq(currencies)
      end
    end
  end
end
