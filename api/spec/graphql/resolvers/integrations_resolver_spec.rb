# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::IntegrationsResolver do
  let(:required_permission) { "customers:view" }
  let(:query) do
    <<~GQL
      query {
        integrations(limit: 5) {
          collection {
            ... on NetsuiteIntegration {
              id
              code
              __typename
            }
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:netsuite_integration) { create(:netsuite_integration, organization:) }
  let(:xero_integration) { create(:xero_integration, organization:) }

  before do
    netsuite_integration
    xero_integration
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", %w[customers:view organization:integrations:view]

  context "when types is present" do
    let(:query) do
      <<~GQL
        query {
          integrations(limit: 5, types: [netsuite]) {
            collection {
              ... on NetsuiteIntegration {
                id
                code
                __typename
              }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of integrations" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      integrations_response = result["data"]["integrations"]

      expect(integrations_response["collection"].count).to eq(1)
      expect(integrations_response["collection"].first["id"]).to eq(netsuite_integration.id)

      expect(integrations_response["metadata"]["currentPage"]).to eq(1)
      expect(integrations_response["metadata"]["totalCount"]).to eq(1)
    end
  end
end
