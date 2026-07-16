# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillableMetrics::Create do
  let(:required_permission) { "billable_metrics:create" }
  let(:membership) { create(:membership) }
  let(:mutation) do
    <<~GQL
      mutation($input: CreateBillableMetricInput!) {
        createBillableMetric(input: $input) {
          id,
          name,
          code,
          aggregationType,
          expression,
          recurring
          organization { id },
          weightedInterval
          filters { key values }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billable_metrics:create"

  it "creates a billable metric" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          name: "New Metric",
          code: "new_metric",
          description: "New metric description",
          aggregationType: "count_agg",
          recurring: false,
          filters: [
            {
              key: "region",
              values: %w[usa europe]
            }
          ]
        }
      }
    )

    result_data = result["data"]["createBillableMetric"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("New Metric")
    expect(result_data["code"]).to eq("new_metric")
    expect(result_data["organization"]["id"]).to eq(membership.organization_id)
    expect(result_data["aggregationType"]).to eq("count_agg")
    expect(result_data["recurring"]).to eq(false)
    expect(result_data["weightedInterval"]).to be_nil
    expect(result_data["filters"].count).to eq(1)
  end
end
