# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BillableMetricResolver do
  subject(:graphql_request) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {billableMetricId: billable_metric.id}
    )
  end

  let(:required_permission) { "billable_metrics:view" }
  let(:query) do
    <<~GQL
      query($billableMetricId: ID!) {
        billableMetric(id: $billableMetricId) {
          id
          name
          hasSubscriptions
          hasActiveSubscriptions
          hasDraftInvoices
          hasPlans
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billable_metric) { create(:billable_metric, organization:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billable_metrics:view"

  it "returns a single billable metric" do
    metric_response = graphql_request["data"]["billableMetric"]

    expect(metric_response["id"]).to eq(billable_metric.id)
    expect(metric_response["hasSubscriptions"]).to eq(false)
    expect(metric_response["hasActiveSubscriptions"]).to eq(false)
    expect(metric_response["hasDraftInvoices"]).to eq(false)
    expect(metric_response["hasPlans"]).to eq(false)
  end

  context "when billable metric has subscriptions" do
    before do
      plan = create(:plan, organization:)
      create(:subscription, :terminated, plan:, organization:)
      create(:standard_charge, plan:, billable_metric:, organization:)
    end

    it "returns true for has subscriptions" do
      metric_response = graphql_request["data"]["billableMetric"]
      expect(metric_response["hasSubscriptions"]).to eq(true)
      expect(metric_response["hasActiveSubscriptions"]).to eq(false)
    end
  end

  context "when billable metric has active subscriptions" do
    before do
      terminated_plan = create(:plan, organization:)
      create(:subscription, :terminated, plan: terminated_plan, organization:)
      create(:standard_charge, plan: terminated_plan, billable_metric:, organization:)

      active_plan = create(:plan, organization:)
      create(:subscription, plan: active_plan, organization:)
      create(:standard_charge, plan: active_plan, billable_metric:, organization:)
    end

    it "returns true for has active subscriptions" do
      metric_response = graphql_request["data"]["billableMetric"]
      expect(metric_response["hasSubscriptions"]).to eq(true)
      expect(metric_response["hasActiveSubscriptions"]).to eq(true)
    end
  end

  context "when billable metric has draft invoices" do
    before do
      customer = create(:customer, organization:)
      plan = create(:plan, organization:)
      plan_2 = create(:plan, organization:)
      create(:subscription, plan:, organization:)
      create(:subscription, plan: plan_2, organization:)
      charge = create(:standard_charge, plan:, billable_metric:, organization:)
      charge_2 = create(:standard_charge, plan: plan_2, billable_metric:, organization:)

      invoice = create(:invoice, customer:, organization:)
      create(:fee, invoice:, charge:)

      draft_invoice = create(:invoice, :draft, customer:, organization:)
      create(:fee, invoice: draft_invoice, charge: charge_2)
      create(:fee, invoice: draft_invoice, charge: charge_2)
    end

    it "returns true for has draft invoices" do
      metric_response = graphql_request["data"]["billableMetric"]
      expect(metric_response["hasDraftInvoices"]).to eq(true)
    end
  end

  context "when billable metric has plans" do
    before do
      plan = create(:plan, organization:)
      plan_2 = create(:plan, organization:)
      create(:subscription, plan:, organization:)
      create(:subscription, plan: plan_2, organization:)
      create(:standard_charge, plan:, billable_metric:, organization:)
      create(:standard_charge, plan: plan_2, billable_metric:, organization:)
    end

    it "returns true for has plans" do
      metric_response = graphql_request["data"]["billableMetric"]
      expect(metric_response["hasPlans"]).to eq(true)
    end
  end

  context "when billable metric is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {billableMetricId: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
