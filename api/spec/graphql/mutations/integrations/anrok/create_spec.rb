# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Integrations::Anrok::Create, :premium do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:code) { "anrok1" }
  let(:name) { "Anrok 1" }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateAnrokIntegrationInput!) {
        createAnrokIntegration(input: $input) {
          id,
          code,
          name,
          apiKey,
          externalAccountId
        }
      }
    GQL
  end

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
            apiKey: "123/456/789",
            connectionId: "this-is-random-uuid"
          }
        }
      )
    end

    it "creates an anrok integration" do
      result_data = result["data"]["createAnrokIntegration"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq(code)
      expect(result_data["name"]).to eq(name)
      expect(result_data["apiKey"]).to eq("••••••••…789")
      expect(result_data["externalAccountId"]).to eq("123")
      expect(Integrations::AnrokIntegration.order(:created_at).last.connection_id).to eq("this-is-random-uuid")
    end

    it_behaves_like "produces a security log", "integration.created"
  end
end
