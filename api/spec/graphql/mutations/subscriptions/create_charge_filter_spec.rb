# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::CreateChargeFilter, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:query) do
    <<~GQL
      mutation($input: CreateSubscriptionChargeFilterInput!) {
        createSubscriptionChargeFilter(input: $input) {
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
      invoiceDisplayName: "New Filter",
      properties: {amount: "100"},
      values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
    }
  end

  before do
    charge
    subscription
    billable_metric_filter
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates a plan override, charge override and charge filter" do
    expect { subject }
      .to change(Plan, :count).by(1)
      .and change(Charge, :count).by(1)
      .and change(ChargeFilter, :count).by(1)

    result_data = subject["data"]["createSubscriptionChargeFilter"]

    expect(result_data["invoiceDisplayName"]).to eq("New Filter")
    expect(result_data["properties"]["amount"]).to eq("100")
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
        invoiceDisplayName: "Test",
        properties: {amount: "100"},
        values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
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
        invoiceDisplayName: "Test",
        properties: {amount: "100"},
        values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["charge"]).to eq(["not_found"])
    end
  end

  context "when values are empty" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        chargeCode: charge.code,
        invoiceDisplayName: "Test",
        properties: {amount: "100"},
        values: {}
      }
    end

    it "returns validation error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("unprocessable_entity")
      expect(result["errors"].first["extensions"]["details"]["values"]).to eq(["value_is_mandatory"])
    end
  end

  context "when subscription already has plan override" do
    let(:overridden_plan) { create(:plan, organization:, parent: plan) }
    let(:subscription) { create(:subscription, organization:, plan: overridden_plan) }
    let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

    before { overridden_charge }

    it "does not create a new plan or charge" do
      expect { subject }
        .to not_change(Plan, :count)
        .and not_change(Charge, :count)
        .and change(ChargeFilter, :count).by(1)
    end

    it "creates the filter on the existing charge override" do
      result_data = subject["data"]["createSubscriptionChargeFilter"]

      filter = ChargeFilter.find(result_data["id"])
      expect(filter.charge_id).to eq(overridden_charge.id)
    end
  end
end
