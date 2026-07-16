# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::IntegrationMappings::Destroy do
  let(:required_permission) { "organization:integrations:update" }
  let(:integration_mapping) { create(:netsuite_mapping, integration:) }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyIntegrationMappingInput!) {
        destroyIntegrationMapping(input: $input) { id }
      }
    GQL
  end

  before { integration_mapping }

  it "deletes an integration mapping" do
    expect do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: integration_mapping.id}
        }
      )
    end.to change(::IntegrationMappings::BaseMapping, :count).by(-1)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  context "when integration mapping is not found" do
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
