# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::BillableMetrics::Update do
  let(:required_permission) { "billable_metrics:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billable_metric) { create(:weighted_sum_billable_metric, organization:) }
  let(:mutation) do
    <<-GQL
      mutation($input: UpdateBillableMetricInput!) {
        updateBillableMetric(input: $input) {
          id,
          name,
          code,
          aggregationType,
          weightedInterval
          recurring
          organization { id },
          filters { key values }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billable_metrics:update"

  it "updates a billable metric" do
    result = execute_query(
      query: mutation,
      input: {
        id: billable_metric.id,
        name: "New Metric",
        code: "new_metric",
        description: "New metric description",
        aggregationType: "count_agg",
        recurring: false,
        weightedInterval: "seconds",
        filters: [
          {
            key: "region",
            values: %w[usa europe]
          }
        ]
      }
    )

    result_data = result["data"]["updateBillableMetric"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("New Metric")
    expect(result_data["code"]).to eq("new_metric")
    expect(result_data["organization"]["id"]).to eq(membership.organization_id)
    expect(result_data["aggregationType"]).to eq("count_agg")
    expect(result_data["weightedInterval"]).to eq("seconds")
    expect(result_data["recurring"]).to eq(false)
    expect(result_data["filters"].count).to eq(1)
  end
end
