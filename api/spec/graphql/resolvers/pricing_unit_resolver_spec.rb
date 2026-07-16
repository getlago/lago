# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PricingUnitResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {pricingUnitId: pricing_unit_id}
    )
  end

  let(:query) do
    <<~GQL
      query($pricingUnitId: ID!) {
        pricingUnit(id: $pricingUnitId) {
          id name code shortName description createdAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:required_permission) { "pricing_units:view" }
  let(:pricing_unit) { create(:pricing_unit, organization: membership.organization) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "pricing_units:view"

  context "when pricing unit with such ID exists in the current organization" do
    let(:pricing_unit_id) { pricing_unit.id }

    it "returns a pricing unit" do
      pricing_unit_response = result["data"]["pricingUnit"]

      expect(pricing_unit_response["id"]).to eq(pricing_unit.id)
      expect(pricing_unit_response["name"]).to eq(pricing_unit.name)
      expect(pricing_unit_response["code"]).to eq(pricing_unit.code)
      expect(pricing_unit_response["shortName"]).to eq(pricing_unit.short_name)
      expect(pricing_unit_response["description"]).to eq(pricing_unit.description)
      expect(pricing_unit_response["createdAt"]).to eq(pricing_unit.created_at.iso8601)
    end
  end

  context "when pricing unit with such ID does not exist in the current organization" do
    let(:pricing_unit_id) { SecureRandom.uuid }

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
