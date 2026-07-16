# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Xero::Create, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:code) { "xero1" }
  let(:name) { "Xero 1" }
  let(:script_endpoint_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateXeroIntegrationInput!) {
        createXeroIntegration(input: $input) {
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

  before { membership.organization.update!(premium_integrations: ["xero"]) }

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
            connectionId: "this-is-random-uuid"
          }
        }
      )
    end

    it "creates a xero integration" do
      result_data = result["data"]["createXeroIntegration"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq(code)
      expect(result_data["name"]).to eq(name)
    end

    it_behaves_like "produces a security log", "integration.created"
  end
end
