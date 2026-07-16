# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::IntegrationItemsResolver do
  let(:required_permission) { "organization:integrations:view" }
  let(:query) do
    <<~GQL
      query($integrationId: ID!, $itemType: IntegrationItemTypeEnum) {
        integrationItems(integrationId: $integrationId, itemType: $itemType, limit: 5) {
          collection { id externalId itemType externalName }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:integration_item) { create(:integration_item, integration:) }
  let(:integration_item2) { create(:integration_item, item_type: "tax", integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  before do
    integration_item
    integration_item2
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:view"

  it "returns a list of integration items" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        integrationId: integration.id,
        itemType: "tax"
      }
    )

    integration_items_response = result["data"]["integrationItems"]

    expect(integration_items_response["collection"].count).to eq(1)
    expect(integration_items_response["collection"].first["id"]).to eq(integration_item2.id)

    expect(integration_items_response["metadata"]["currentPage"]).to eq(1)
    expect(integration_items_response["metadata"]["totalCount"]).to eq(1)
  end

  context "without integration id" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        permissions: required_permission,
        query:
      )

      expect_graphql_error(
        result:,
        message: "Variable $integrationId of type ID! was provided invalid value"
      )
    end
  end
end
