# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Xero::Update, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:update" }
  let(:integration) { create(:xero_integration, organization:) }
  let(:organization) { membership.organization }
  let(:membership) { create(:membership) }
  let(:code) { "xero1" }
  let(:name) { "Xero 1" }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateXeroIntegrationInput!) {
        updateXeroIntegration(input: $input) {
          id,
          code,
          name,
          syncInvoices,
          syncCreditNotes,
          syncPayments
        }
      }
    GQL
  end

  before do
    integration
    membership.organization.update!(premium_integrations: ["xero"])
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
            code:
          }
        }
      )
    end

    it "updates a xero integration" do
      result_data = result["data"]["updateXeroIntegration"]

      expect(result_data["name"]).to eq(name)
      expect(result_data["code"]).to eq(code)
    end

    it_behaves_like "produces a security log", "integration.updated"
  end
end
