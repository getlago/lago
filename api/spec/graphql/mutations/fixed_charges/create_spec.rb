# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::FixedCharges::Create, type: :graphql do
  let(:required_permission) { "charges:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: FixedChargeCreateInput!) {
        createFixedCharge(input: $input) {
          id
          code
          invoiceDisplayName
          chargeModel
          payInAdvance
          prorated
          units
          properties {
            amount
          }
          addOn {
            id
          }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "charges:create"

  it "creates a fixed charge" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          planId: plan.id,
          addOnId: add_on.id,
          chargeModel: "standard",
          code: "my_fixed_charge",
          invoiceDisplayName: "My Fixed Charge",
          payInAdvance: false,
          prorated: false,
          units: "10",
          properties: {
            amount: "100"
          }
        }
      }
    )

    result_data = result["data"]["createFixedCharge"]

    expect(result_data["id"]).to be_present
    expect(result_data["code"]).to eq("my_fixed_charge")
    expect(result_data["invoiceDisplayName"]).to eq("My Fixed Charge")
    expect(result_data["chargeModel"]).to eq("standard")
    expect(result_data["payInAdvance"]).to eq(false)
    expect(result_data["prorated"]).to eq(false)
    expect(result_data["units"]).to eq("10")
    expect(result_data["properties"]["amount"]).to eq("100")
    expect(result_data["addOn"]["id"]).to eq(add_on.id)
  end

  context "when plan does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            planId: "unknown",
            addOnId: add_on.id,
            chargeModel: "standard",
            properties: {amount: "100"}
          }
        }
      )

      expect_not_found(result)
    end
  end
end
