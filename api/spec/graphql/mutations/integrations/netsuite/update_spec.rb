# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Netsuite::Update, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:netsuite_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:code) { "netsuite1" }
  let(:name) { "Netsuite 1" }
  let(:script_endpoint_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateNetsuiteIntegrationInput!) {
        updateNetsuiteIntegration(input: $input) {
          id,
          code,
          name,
          clientId,
          clientSecret,
          syncInvoices,
          syncCreditNotes,
          syncPayments,
          scriptEndpointUrl
        }
      }
    GQL
  end

  before do
    integration
    membership.organization.update!(premium_integrations: ["netsuite"])
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
            scriptEndpointUrl: script_endpoint_url
          }
        }
      )
    end

    it "updates a netsuite integration" do
      result_data = result["data"]["updateNetsuiteIntegration"]

      expect(result_data["name"]).to eq(name)
      expect(result_data["code"]).to eq(code)
      expect(result_data["scriptEndpointUrl"]).to eq(script_endpoint_url)
    end

    it_behaves_like "produces a security log", "integration.updated"
  end
end
