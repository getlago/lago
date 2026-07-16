# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Salesforce::Update, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:salesforce_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:name) { "Salesforce 1" }
  let(:code) { "salesforce_work" }
  let(:instance_id) { "salesforce_link" }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateSalesforceIntegrationInput!) {
        updateSalesforceIntegration(input: $input) {
          id,
          code,
          name,
          instanceId
        }
      }
    GQL
  end

  before do
    integration
    membership.organization.update!(premium_integrations: ["salesforce"])
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
            name:,
            code:,
            instanceId: instance_id
          }
        }
      )
    end

    it "updates a salesforce integration" do
      result_data = result["data"]["updateSalesforceIntegration"]

      expect(result_data["name"]).to eq(name)
      expect(result_data["code"]).to eq(code)
      expect(result_data["instanceId"]).to eq(instance_id)
    end

    it_behaves_like "produces a security log", "integration.updated"
  end
end
