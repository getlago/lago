# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::ApiKeys::Update, :premium do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {input: input_params}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: UpdateApiKeyInput!) {
        updateApiKey(input: $input) { id name permissions }
      }
    GQL
  end

  let(:required_permission) { "developers:keys:manage" }
  let!(:membership) { create(:membership) }
  let(:input_params) { {id: api_key.id, permissions:, name:} }
  let(:permissions) { api_key.permissions.merge("add_on" => ["read"]) }
  let(:name) { Faker::Lorem.words.join(" ") }

  include_context "with mocked security logger"

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:keys:manage"

  context "when api key with such ID exists in the current organization" do
    let(:api_key) { membership.organization.api_keys.first }

    before { membership.organization.update!(premium_integrations: ["api_permissions"]) }

    context "when permissions are present" do
      it "returns updated api key" do
        api_key_response = result["data"]["updateApiKey"]

        expect(api_key_response["id"]).to eq(api_key.id)
        expect(api_key_response["name"]).to eq(name)
        expect(api_key_response["permissions"]).to eq(permissions)
      end

      it_behaves_like "produces a security log", "api_key.updated" do
        before { result }
      end
    end

    context "when permissions are missing" do
      let(:input_params) { {id: api_key.id, name:} }

      it "returns updated api key" do
        api_key_response = result["data"]["updateApiKey"]

        expect(api_key_response["id"]).to eq(api_key.id)
        expect(api_key_response["name"]).to eq(name)
        expect(api_key_response["permissions"]).to eq(api_key.permissions)
      end
    end
  end

  context "when api key with such ID does not exist in the current organization" do
    let!(:api_key) { create(:api_key) }

    it "does not change the api key" do
      expect { result }.not_to change { api_key.reload.name }
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
