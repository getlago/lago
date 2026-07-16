# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Okta::Update, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:okta_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateOktaIntegrationInput!) {
        updateOktaIntegration(input: $input) {
          id,
          code,
          name,
          clientId,
          clientSecret,
          domain,
          organizationName,
        }
      }
    GQL
  end

  before do
    integration
    membership.organization.update!(premium_integrations: ["okta"])
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  context "with valid input" do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: integration.id,
            domain: "foo.bar",
            organizationName: "Footest"
          }
        }
      )
    end

    it "updates an okta integration" do
      result_data = result["data"]["updateOktaIntegration"]

      expect(result_data["domain"]).to eq("foo.bar")
      expect(result_data["organizationName"]).to eq("Footest")
    end

    it_behaves_like "produces a security log", "integration.updated"
  end
end
