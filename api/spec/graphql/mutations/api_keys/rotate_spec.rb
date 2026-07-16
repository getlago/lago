# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::ApiKeys::Rotate do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {input: {id: api_key.id, expiresAt: expires_at, name:}}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: RotateApiKeyInput!) {
        rotateApiKey(input: $input) { id value name createdAt expiresAt }
      }
    GQL
  end

  let(:required_permission) { "developers:keys:manage" }
  let!(:membership) { create(:membership) }
  let(:expires_at) { generate(:future_date).iso8601 }
  let(:name) { Faker::Lorem.words.join(" ") }

  include_context "with mocked security logger"

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:keys:manage"

  context "when api key with such ID exists in the current organization", :premium do
    let(:api_key) { membership.organization.api_keys.first }

    it "expires the api key" do
      expect { result }
        .to change { api_key.reload.expires_at&.iso8601 }
        .to(expires_at)
    end

    it "returns newly created api key" do
      api_key_response = result["data"]["rotateApiKey"]
      new_api_key = membership.organization.api_keys.order(:created_at).last

      expect(api_key_response["id"]).to eq(new_api_key.id)
      expect(api_key_response["value"]).to eq(new_api_key.value)
      expect(api_key_response["name"]).to eq(name)
      expect(api_key_response["createdAt"]).to eq(new_api_key.created_at.iso8601)
      expect(api_key_response["expiresAt"]).to be_nil
    end

    it_behaves_like "produces a security log", "api_key.rotated" do
      before { result }
    end
  end

  context "when api key with such ID does not exist in the current organization" do
    let!(:api_key) { create(:api_key) }

    it "does not change the api key" do
      expect { result }.not_to change { api_key.reload.expires_at }
    end

    it "does not create an api key" do
      expect { result }.not_to change(ApiKey, :count)
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
