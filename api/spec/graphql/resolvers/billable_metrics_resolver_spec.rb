# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BillableMetricsResolver do
  let(:required_permission) { "billable_metrics:view" }
  let(:query) do
    <<~GQL
      query {
        billableMetrics(limit: 5) {
          collection {
            id
            name
            filters { key values }
          }
          metadata { currentPage totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billable_metrics:view"

  it "returns a list of billable metrics" do
    metric = create(:billable_metric, organization:)

    filter1 = create(:billable_metric_filter, billable_metric: metric, key: "cloud", values: %w[aws gcp azure])
    filter2 = create(:billable_metric_filter, billable_metric: metric, key: "region", values: %w[usa europe asia])

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    expect(result["data"]["billableMetrics"]["collection"].count).to eq(organization.billable_metrics.count)
    expect(result["data"]["billableMetrics"]["collection"].first["id"]).to eq(metric.id)

    expect(result["data"]["billableMetrics"]["collection"].first["filters"].first["key"]).to eq(filter1.key)
    expect(result["data"]["billableMetrics"]["collection"].first["filters"].first["values"])
      .to match_array(filter1.values)

    expect(result["data"]["billableMetrics"]["collection"].first["filters"].second["key"]).to eq(filter2.key)
    expect(result["data"]["billableMetrics"]["collection"].first["filters"].second["values"])
      .to match_array(filter2.values)

    expect(result["data"]["billableMetrics"]["metadata"]["currentPage"]).to eq(1)
    expect(result["data"]["billableMetrics"]["metadata"]["totalCount"]).to eq(1)
  end
end
