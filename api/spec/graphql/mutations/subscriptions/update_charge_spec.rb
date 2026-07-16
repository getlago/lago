# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::UpdateCharge, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:query) do
    <<~GQL
      mutation($input: UpdateSubscriptionChargeInput!) {
        updateSubscriptionCharge(input: $input) {
          id
          invoiceDisplayName
          minAmountCents
          properties {
            amount
          }
          parentId
        }
      }
    GQL
  end

  let(:input) do
    {
      subscriptionId: subscription.id,
      chargeCode: charge.code,
      invoiceDisplayName: "Updated Charge",
      minAmountCents: 500,
      properties: {amount: "200"}
    }
  end

  before do
    charge
    subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates a plan override and charge override" do
    expect { subject }.to change(Plan, :count).by(1).and change(Charge, :count).by(1)

    result_data = subject["data"]["updateSubscriptionCharge"]

    expect(result_data["invoiceDisplayName"]).to eq("Updated Charge")
    expect(result_data["minAmountCents"]).to eq("500")
    expect(result_data["properties"]["amount"]).to eq("200")
    expect(result_data["parentId"]).to eq(charge.id)
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
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["charge"]).to eq(["not_found"])
    end
  end

  context "when subscription already has plan override" do
    let(:overridden_plan) { create(:plan, organization:, parent: plan) }
    let(:subscription) { create(:subscription, organization:, plan: overridden_plan) }
    let(:overridden_charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

    before { overridden_charge }

    it "does not create a new plan" do
      expect { subject }.not_to change(Plan, :count)
    end

    it "updates the existing charge override" do
      result_data = subject["data"]["updateSubscriptionCharge"]

      expect(result_data["id"]).to eq(overridden_charge.id)
      expect(result_data["invoiceDisplayName"]).to eq("Updated Charge")
      expect(result_data["minAmountCents"]).to eq("500")
    end
  end

  context "with filters" do
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:, organization:, key: "region", values: %w[us eu]) }
    let(:input) do
      {
        subscriptionId: subscription.id,
        chargeCode: charge.code,
        properties: {amount: "1"},
        filters: [
          {
            invoiceDisplayName: "EU",
            properties: {amount: "11"},
            values: {billable_metric_filter.key => %w[eu]}
          }
        ]
      }
    end

    before { billable_metric_filter }

    it "creates the charge override with its filters" do
      result_data = subject["data"]["updateSubscriptionCharge"]

      override = Charge.find(result_data["id"])
      expect(override.filters.count).to eq(1)
      expect(override.filters.first.properties).to eq("amount" => "11")
    end
  end

  context "with taxes" do
    let(:tax) { create(:tax, organization:) }
    let(:input) do
      {
        subscriptionId: subscription.id,
        chargeCode: charge.code,
        invoiceDisplayName: "Taxed Charge",
        taxCodes: [tax.code]
      }
    end

    it "creates a charge override with taxes" do
      subject

      result_data = subject["data"]["updateSubscriptionCharge"]
      expect(result_data["invoiceDisplayName"]).to eq("Taxed Charge")
    end
  end
end
