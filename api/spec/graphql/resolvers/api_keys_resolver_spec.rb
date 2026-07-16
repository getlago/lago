# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::ApiKeysResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )
  end

  let(:query) do
    <<~GQL
      query {
        apiKeys {
          collection { id value createdAt }
          metadata { currentPage, totalCount totalPages }
        }
      }
    GQL
  end

  let(:organization) { create(:api_key).organization }
  let(:membership) { create(:membership, organization:) }
  let(:required_permission) { "developers:keys:manage" }
  let(:api_key) { membership.organization.api_keys.first }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "developers:keys:manage"

  it "returns a list of api keys" do
    api_key_response = result["data"]["apiKeys"]

    expect(api_key_response["collection"].first["id"]).to eq(api_key.id)
    expect(api_key_response["collection"].first["value"]).to eq("••••••••" + api_key.value.last(3))
    expect(api_key_response["collection"].first["createdAt"]).to eq(api_key.created_at.iso8601)

    expect(api_key_response["metadata"]["currentPage"]).to eq(1)
    expect(api_key_response["metadata"]["totalCount"]).to eq(1)
    expect(api_key_response["metadata"]["totalPages"]).to eq(1)
  end

  context "when pagination is provided" do
    let(:query) do
      <<~GQL
        query($limit: Int, $page: Int) {
          apiKeys(limit: $limit, page: $page) {
            collection { id value name createdAt }
            metadata { currentPage, totalCount totalPages}
          }
        }
      GQL
    end

    before do
      create(:api_key, organization: membership.organization, created_at: 1.day.ago, name: "Older API Key")
    end

    def fetch_api_keys(page: 1, limit: 1)
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          limit:,
          page:
        }
      )
    end

    it "returns a list of api keys" do
      [
        {page: 1, limit: 1, expected_total_pages: 2, expected_api_key_names: ["Older API Key"]},
        {page: 2, limit: 1, expected_total_pages: 2, expected_api_key_names: ["API Key"]},
        {page: 1, limit: 2, expected_total_pages: 1, expected_api_key_names: ["Older API Key", "API Key"]}
      ].each do |test_case|
        page, limit, expected_total_pages, expected_api_key_names = test_case.values_at(:page, :limit, :expected_total_pages, :expected_api_key_names)
        api_key_response = fetch_api_keys(page:, limit:)["data"]["apiKeys"]

        collection = api_key_response["collection"]
        expect(collection.size).to eq(limit)
        expect(collection.map { |api_key| api_key["name"] }).to eq(expected_api_key_names)

        expect(api_key_response["metadata"]["currentPage"]).to eq(page)
        expect(api_key_response["metadata"]["totalCount"]).to eq(2)
        expect(api_key_response["metadata"]["totalPages"]).to eq(expected_total_pages)
      end
    end
  end
end
