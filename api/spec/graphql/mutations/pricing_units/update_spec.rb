# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PricingUnits::Update, :premium do
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
      mutation($input: UpdatePricingUnitInput!) {
        updatePricingUnit(input: $input) { id name shortName description }
      }
    GQL
  end

  let(:required_permission) { "pricing_units:update" }
  let!(:membership) { create(:membership) }
  let(:input_params) { {id: pricing_unit.id, name:, shortName: short_name, description:} }
  let(:name) { "Updated Name" }
  let(:short_name) { "CR" }
  let(:description) { "Updated Description" }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "pricing_units:update"

  context "when pricing unit with such ID exists in the current organization" do
    let(:pricing_unit) { create(:pricing_unit, organization: membership.organization) }

    context "with valid params" do
      it "returns updated pricing unit" do
        pricing_unit_response = result["data"]["updatePricingUnit"]

        expect(pricing_unit_response["id"]).to eq(pricing_unit.id)
        expect(pricing_unit_response["name"]).to eq(name)
        expect(pricing_unit_response["shortName"]).to eq(short_name)
        expect(pricing_unit_response["description"]).to eq(description)
      end
    end

    context "with invalid params" do
      let(:name) { "" }

      it "does not change the pricing unit" do
        expect { result }.not_to change { pricing_unit.reload.attributes }
      end

      it "returns validation error" do
        expect_graphql_error(result:, message: "unprocessable_entity")
      end
    end
  end

  context "when pricing unit with such ID does not exist in the current organization" do
    let!(:pricing_unit) { create(:pricing_unit) }

    it "does not change the pricing unit" do
      expect { result }.not_to change { pricing_unit.reload.attributes }
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
