# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Okta::Create, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateOktaIntegrationInput!) {
        createOktaIntegration(input: $input) {
          id,
          name,
          code,
          clientId,
          clientSecret,
          domain,
        }
      }
    GQL
  end

  before { membership.organization.update!(premium_integrations: ["okta"]) }

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
            clientId: "123",
            clientSecret: "456",
            domain: "foo.bar",
            organizationName: "Foobar"
          }
        }
      )
    end

    it "creates an okta integration" do
      result_data = result["data"]["createOktaIntegration"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq("okta")
      expect(result_data["name"]).to eq("Okta Integration")
    end

    it_behaves_like "produces a security log", "integration.created"
  end
end
