# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationCollectionMappings::Destroy do
  let(:required_permission) { "organization:integrations:update" }
  let(:integration_collection_mapping) { create(:netsuite_collection_mapping, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyIntegrationCollectionMappingInput!) {
        destroyIntegrationCollectionMapping(input: $input) { id }
      }
    GQL
  end

  before { integration_collection_mapping }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "deletes an integration collection mapping" do
    expect do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: integration_collection_mapping.id}
        }
      )
    end.to change(::IntegrationCollectionMappings::BaseCollectionMapping, :count).by(-1)
  end

  context "when integration collection mapping is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: "123456"}
        }
      )

      expect_not_found(result)
    end
  end
end
