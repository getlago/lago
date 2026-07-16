# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::UpdateChargeFilter, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:charge_filter) do
    create(:charge_filter, charge:, organization:, properties: {amount: "50"}).tap do |filter|
      create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
    end
  end
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:query) do
    <<~GQL
      mutation($input: UpdateSubscriptionChargeFilterInput!) {
        updateSubscriptionChargeFilter(input: $input) {
          id
          invoiceDisplayName
          properties {
            amount
          }
          values
        }
      }
    GQL
  end

  let(:input) do
    {
      subscriptionId: subscription.id,
      chargeCode: charge.code,
      values: {billable_metric_filter.key => [billable_metric_filter.values.first]},
      invoiceDisplayName: "Updated Filter",
      properties: {amount: "200"}
    }
  end

  before do
    charge_filter
    subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates a plan override, charge override and charge filter override" do
    expect { subject }
      .to change(Plan, :count).by(1)
      .and change(Charge, :count).by(1)
      .and change(ChargeFilter, :count).by(1)

    result_data = subject["data"]["updateSubscriptionChargeFilter"]

    expect(result_data["invoiceDisplayName"]).to eq("Updated Filter")
    expect(result_data["properties"]["amount"]).to eq("200")
    expect(result_data["values"]).to eq({billable_metric_filter.key => [billable_metric_filter.values.first]})
  end

  it "updates the subscription to use the overridden plan" do
    subject

    subscription.reload
    expect(subscription.plan.parent_id).to eq(plan.id)
  end

  context "when subscription does not exist" do
    let(:input) do
      {
        subscriptionId: "invalid-id",
        chargeCode: charge.code,
        values: {billable_metric_filter.key => [billable_metric_filter.values.first]},
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["subscription"]).to eq(["not_found"])
    end
  end

  context "when charge does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        chargeCode: "invalid-code",
        values: {billable_metric_filter.key => [billable_metric_filter.values.first]},
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["charge"]).to eq(["not_found"])
    end
  end

  context "when charge filter does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        chargeCode: charge.code,
        values: {"nonexistent" => ["value"]},
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["chargeFilter"]).to eq(["not_found"])
    end
  end

  context "when subscription already has plan override with charge and filter" do
    let(:overridden_plan) { create(:plan, organization:, parent: plan) }
    let(:subscription) { create(:subscription, organization:, plan: overridden_plan) }
    let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }
    let(:overridden_filter) do
      create(:charge_filter, charge: overridden_charge, organization:, properties: {amount: "75"}).tap do |filter|
        create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
      end
    end

    before { overridden_filter }

    it "does not create new plan, charge, or filter" do
      expect { subject }
        .to not_change(Plan, :count)
        .and not_change(Charge, :count)
        .and not_change(ChargeFilter, :count)
    end

    it "updates the existing filter override" do
      result_data = subject["data"]["updateSubscriptionChargeFilter"]

      expect(result_data["id"]).to eq(overridden_filter.id)
      expect(result_data["invoiceDisplayName"]).to eq("Updated Filter")
      expect(result_data["properties"]["amount"]).to eq("200")
    end
  end
end
