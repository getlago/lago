# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Salesforce::Create, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:name) { "Salesforce 1" }
  let(:code) { "salesforce_test" }
  let(:script_endpoint_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateSalesforceIntegrationInput!) {
        createSalesforceIntegration(input: $input) {
          id,
          code,
          name,
          instanceId
        }
      }
    GQL
  end

  before { membership.organization.update!(premium_integrations: ["salesforce"]) }

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
            name:,
            code:,
            instanceId: "this-is-random-uuid"
          }
        }
      )
    end

    it "creates a salesforce integration" do
      result_data = result["data"]["createSalesforceIntegration"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq(code)
      expect(result_data["name"]).to eq(name)
    end

    it_behaves_like "produces a security log", "integration.created"
  end
end
