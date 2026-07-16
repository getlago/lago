# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::IntegrationResolver do
  let(:required_permission) { "organization:integrations:view" }
  let(:query) do
    <<~GQL
      query($integrationId: ID!) {
        integration(id: $integrationId) {
          ... on NetsuiteIntegration {
            id
            code
            name
            scriptEndpointUrl
            __typename
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:netsuite_integration) { create(:netsuite_integration, organization:) }

  before do
    customer
    netsuite_integration
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:view"

  it "returns a single integration" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {integrationId: netsuite_integration.id}
    )

    integration_response = result["data"]["integration"]

    expect(integration_response["id"]).to eq(netsuite_integration.id)
    expect(integration_response["code"]).to eq(netsuite_integration.code)
    expect(integration_response["name"]).to eq(netsuite_integration.name)
    expect(integration_response["scriptEndpointUrl"]).to eq(netsuite_integration.script_endpoint_url)
  end

  context "when integration is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {integrationId: "foo"}
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
