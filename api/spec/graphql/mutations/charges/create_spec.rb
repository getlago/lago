# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Charges::Create, type: :graphql do
  let(:required_permission) { "charges:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: ChargeCreateInput!) {
        createCharge(input: $input) {
          id
          code
          invoiceDisplayName
          chargeModel
          payInAdvance
          prorated
          invoiceable
          minAmountCents
          properties {
            amount
          }
          billableMetric {
            id
          }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "charges:create"

  it "creates a charge" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          planId: plan.id,
          billableMetricId: billable_metric.id,
          chargeModel: "standard",
          code: "my_charge",
          invoiceDisplayName: "My Charge",
          payInAdvance: false,
          prorated: false,
          properties: {
            amount: "10"
          }
        }
      }
    )

    result_data = result["data"]["createCharge"]

    expect(result_data["id"]).to be_present
    expect(result_data["code"]).to eq("my_charge")
    expect(result_data["invoiceDisplayName"]).to eq("My Charge")
    expect(result_data["chargeModel"]).to eq("standard")
    expect(result_data["payInAdvance"]).to eq(false)
    expect(result_data["prorated"]).to eq(false)
    expect(result_data["properties"]["amount"]).to eq("10")
    expect(result_data["billableMetric"]["id"]).to eq(billable_metric.id)
  end

  context "with filters" do
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, values: %w[value1 value2]) }

    it "creates a charge with filters" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            planId: plan.id,
            billableMetricId: billable_metric.id,
            chargeModel: "standard",
            code: "charge_with_filters",
            properties: {
              amount: "10"
            },
            filters: [
              {
                invoiceDisplayName: "Filter 1",
                properties: {amount: "20"},
                values: {billable_metric_filter.key.to_s => ["value1"]}
              }
            ]
          }
        }
      )

      result_data = result["data"]["createCharge"]
      expect(result_data["id"]).to be_present
    end
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
            billableMetricId: billable_metric.id,
            chargeModel: "standard",
            properties: {amount: "10"}
          }
        }
      )

      expect_not_found(result)
    end
  end
end
