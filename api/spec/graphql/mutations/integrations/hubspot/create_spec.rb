# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Hubspot::Create, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:code) { "hubspot1" }
  let(:name) { "Hubspot 1" }
  let(:script_endpoint_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateHubspotIntegrationInput!) {
        createHubspotIntegration(input: $input) {
          id,
          code,
          name,
          connectionId,
          defaultTargetedObject,
          syncInvoices,
          syncSubscriptions
        }
      }
    GQL
  end

  before { membership.organization.update!(premium_integrations: ["hubspot"]) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:create"

  context "with valid input" do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            code:,
            name:,
            connectionId: "this-is-random-uuid",
            defaultTargetedObject: "companies"
          }
        }
      )
    end

    it "creates a hubspot integration" do
      result_data = result["data"]["createHubspotIntegration"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq(code)
      expect(result_data["name"]).to eq(name)
    end

    it_behaves_like "produces a security log", "integration.created"
  end
end
