# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::ChargeFilters::Create, type: :graphql do
  let(:required_permission) { "charges:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, values: %w[value1 value2 value3]) }
  let(:charge) { create(:standard_charge, plan:, billable_metric:) }

  let(:mutation) do
    <<~GQL
      mutation($input: ChargeFilterCreateInput!) {
        createChargeFilter(input: $input) {
          id
          chargeCode
          invoiceDisplayName
          properties {
            amount
          }
          values
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "charges:create"

  it "creates a charge filter" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          chargeId: charge.id,
          invoiceDisplayName: "My Filter",
          properties: {
            amount: "50"
          },
          values: {
            billable_metric_filter.key.to_s => ["value1", "value2"]
          }
        }
      }
    )

    result_data = result["data"]["createChargeFilter"]

    expect(result_data["id"]).to be_present
    expect(result_data["chargeCode"]).to eq(charge.code)
    expect(result_data["invoiceDisplayName"]).to eq("My Filter")
    expect(result_data["properties"]["amount"]).to eq("50")
    expect(result_data["values"][billable_metric_filter.key]).to eq(["value1", "value2"])
  end

  context "when charge does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            chargeId: "unknown",
            properties: {amount: "50"},
            values: {"key" => ["value"]}
          }
        }
      )

      expect_not_found(result)
    end
  end

  context "when values are not provided" do
    it "returns a validation error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            chargeId: charge.id,
            properties: {amount: "50"},
            values: {}
          }
        }
      )

      expect_unprocessable_entity(result)
    end
  end
end
