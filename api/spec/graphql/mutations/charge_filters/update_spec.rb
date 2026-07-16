# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::ChargeFilters::Update, type: :graphql do
  let(:required_permission) { "charges:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }
  let(:charge_filter) { create(:charge_filter, charge:) }

  let(:mutation) do
    <<~GQL
      mutation($input: ChargeFilterUpdateInput!) {
        updateChargeFilter(input: $input) {
          id
          invoiceDisplayName
          properties {
            amount
          }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "charges:update"

  it "updates a charge filter" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: charge_filter.id,
          invoiceDisplayName: "Updated Filter",
          properties: {
            amount: "75"
          }
        }
      }
    )

    result_data = result["data"]["updateChargeFilter"]

    expect(result_data["id"]).to eq(charge_filter.id)
    expect(result_data["invoiceDisplayName"]).to eq("Updated Filter")
    expect(result_data["properties"]["amount"]).to eq("75")
  end

  context "with cascade_updates" do
    it "updates a charge filter with cascade" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: charge_filter.id,
            invoiceDisplayName: "Updated Filter with Cascade",
            cascadeUpdates: true
          }
        }
      )

      result_data = result["data"]["updateChargeFilter"]

      expect(result_data["id"]).to eq(charge_filter.id)
      expect(result_data["invoiceDisplayName"]).to eq("Updated Filter with Cascade")
    end
  end

  context "when charge filter does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: "unknown",
            invoiceDisplayName: "Updated"
          }
        }
      )

      expect_not_found(result)
    end
  end
end
