# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::TaxesResolver do
  let(:query) do
    <<~GQL
      query {
        taxes(limit: 5) {
          collection { id name }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, organization:) }

  before { tax }

  it "returns a list of taxes" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:
    )

    taxes_response = result["data"]["taxes"]

    expect(taxes_response["collection"].first).to include(
      "id" => tax.id,
      "name" => tax.name
    )

    expect(taxes_response["metadata"]).to include(
      "currentPage" => 1,
      "totalCount" => 1
    )
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(current_user: membership.user, query:)

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when not member of the organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: create(:organization),
        query:
      )

      expect_graphql_error(result:, message: "Not in organization")
    end
  end
end
