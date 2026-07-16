# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::ApiKeys::Destroy do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {input: {id: api_key.id}}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: DestroyApiKeyInput!) {
        destroyApiKey(input: $input) { id expiresAt }
      }
    GQL
  end

  let(:required_permission) { "developers:keys:manage" }
  let!(:membership) { create(:membership) }

  include_context "with mocked security logger"

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:keys:manage"

  context "when api key with such ID exists in the current organization" do
    let(:api_key) { create(:api_key, organization: membership.organization) }

    it "expires the api key" do
      expect { result }.to change { api_key.reload.expires_at }.from(nil).to(Time)
    end

    it "returns expired api key" do
      api_key_response = result["data"]["destroyApiKey"]
      api_key.reload

      expect(api_key_response["id"]).to eq(api_key.id)
      expect(api_key_response["expiresAt"]).to eq(api_key.expires_at.iso8601)
    end

    it_behaves_like "produces a security log", "api_key.deleted" do
      before { result }
    end
  end

  context "when api key with such ID does not exist in the current organization" do
    let!(:api_key) { create(:api_key) }

    it "does not change the api key" do
      expect { result }.not_to change { api_key.reload.expires_at }
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
