# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::ApiKeyResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {apiKeyId: api_key_id}
    )
  end

  let(:query) do
    <<~GQL
      query($apiKeyId: ID!) {
        apiKey(id: $apiKeyId) {
          id value createdAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:required_permission) { "developers:keys:manage" }
  let(:api_key) { membership.organization.api_keys.first }

  before { create(:api_key) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:keys:manage"

  context "when api key with such ID exists in the current organization" do
    let(:api_key_id) { api_key.id }

    it "returns an api key" do
      api_key_response = result["data"]["apiKey"]

      expect(api_key_response["id"]).to eq(api_key.id)
      expect(api_key_response["value"]).to eq(api_key.value)
      expect(api_key_response["createdAt"]).to eq(api_key.created_at.iso8601)
    end
  end

  context "when api key with such ID does not exist in the current organization" do
    let(:api_key_id) { SecureRandom.uuid }

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
