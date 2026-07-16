# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PricingUnitsResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {searchTerm: "token"}
    )
  end

  let(:query) do
    <<~GQL
      query($searchTerm: String) {
        pricingUnits(page: 2, limit: 1, searchTerm: $searchTerm) {
          collection { id name code shortName description createdAt }
          metadata {
            currentPage
            totalCount
            totalPages
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:required_permission) { "pricing_units:view" }
  let(:pricing_unit) { create(:pricing_unit, name: "Compute token", organization:) }

  before do
    create(:pricing_unit, name: "Cloud token", organization:)
    pricing_unit
    create(:pricing_unit, code: "token", organization:)
    create(:pricing_unit, name: "coin", code: "coin", organization:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "pricing_units:view"

  it "returns a list of pricing units matching search term" do
    pricing_units_response = result["data"]["pricingUnits"]

    expect(pricing_units_response["collection"].first["id"]).to eq(pricing_unit.id)
    expect(pricing_units_response["collection"].first["name"]).to eq(pricing_unit.name)
    expect(pricing_units_response["collection"].first["code"]).to eq(pricing_unit.code)
    expect(pricing_units_response["collection"].first["shortName"]).to eq(pricing_unit.short_name)
    expect(pricing_units_response["collection"].first["description"]).to eq(pricing_unit.description)
    expect(pricing_units_response["collection"].first["createdAt"]).to eq(pricing_unit.created_at.iso8601)

    expect(pricing_units_response["collection"].size).to eq(1)
    expect(pricing_units_response["metadata"]["currentPage"]).to eq(2)
    expect(pricing_units_response["metadata"]["totalCount"]).to eq(3)
    expect(pricing_units_response["metadata"]["totalPages"]).to eq(3)
  end
end
