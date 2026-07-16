# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PricingUnits::Create do
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
      mutation($input: CreatePricingUnitInput!) {
        createPricingUnit(input: $input) { id name code shortName description }
      }
    GQL
  end

  let(:required_permission) { "pricing_units:create" }
  let(:membership) { create(:membership) }

  let(:input_params) do
    {
      name: "Cloud token",
      code:,
      shortName: "CT",
      description: ""
    }
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "pricing_units:create"

  context "with premium organization", :premium do
    context "with valid params" do
      let(:code) { "cloud_token" }

      it "creates a new pricing unit" do
        expect { result }.to change(PricingUnit, :count).by(1)
      end

      it "returns created pricing unit" do
        pricing_unit_response = result["data"]["createPricingUnit"]

        expect(pricing_unit_response["name"]).to eq(input_params[:name])
        expect(pricing_unit_response["code"]).to eq(input_params[:code])
        expect(pricing_unit_response["shortName"]).to eq(input_params[:shortName])
        expect(pricing_unit_response["description"]).to eq(input_params[:description])
      end
    end

    context "with invalid params" do
      let(:code) { "" }

      it "does not create a new pricing unit" do
        expect { result }.not_to change(PricingUnit, :count)
      end

      it "returns validation error" do
        expect_graphql_error(result:, message: "unprocessable_entity")
      end
    end
  end

  context "with free organization" do
    let(:code) { "cloud_token" }

    it "does not create a new pricing unit" do
      expect { result }.not_to change(PricingUnit, :count)
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "feature_unavailable")
    end
  end
end
