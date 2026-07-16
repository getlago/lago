# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Subscriptions::UpdateFixedCharge, :premium do
  subject { execute_query(query:, input:) }

  let(:required_permission) { "subscriptions:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, organization:, add_on:) }
  let(:subscription) { create(:subscription, organization:, plan:) }

  let(:query) do
    <<~GQL
      mutation($input: UpdateSubscriptionFixedChargeInput!) {
        updateSubscriptionFixedCharge(input: $input) {
          id
          invoiceDisplayName
          units
          parentId
        }
      }
    GQL
  end

  let(:input) do
    {
      subscriptionId: subscription.id,
      fixedChargeCode: fixed_charge.code,
      invoiceDisplayName: "Updated Fixed Charge",
      units: "20"
    }
  end

  before do
    fixed_charge
    subscription
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires permission", "subscriptions:update"

  it "creates a plan override and fixed charge override" do
    expect { subject }.to change(Plan, :count).by(1).and change(FixedCharge, :count).by(1)

    result_data = subject["data"]["updateSubscriptionFixedCharge"]

    expect(result_data["invoiceDisplayName"]).to eq("Updated Fixed Charge")
    expect(result_data["units"]).to eq("20")
    expect(result_data["parentId"]).to eq(fixed_charge.id)
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
        fixedChargeCode: fixed_charge.code,
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["subscription"]).to eq(["not_found"])
    end
  end

  context "when fixed charge does not exist" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        fixedChargeCode: "invalid-code",
        invoiceDisplayName: "Test"
      }
    end

    it "returns not found error" do
      result = subject

      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["details"]["fixedCharge"]).to eq(["not_found"])
    end
  end

  context "when subscription already has plan override" do
    let(:overridden_plan) { create(:plan, organization:, parent: plan) }
    let(:subscription) { create(:subscription, organization:, plan: overridden_plan) }
    let(:overridden_fixed_charge) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: fixed_charge, code: fixed_charge.code) }

    before { overridden_fixed_charge }

    it "does not create a new plan" do
      expect { subject }.not_to change(Plan, :count)
    end

    it "updates the existing fixed charge override" do
      result_data = subject["data"]["updateSubscriptionFixedCharge"]

      expect(result_data["id"]).to eq(overridden_fixed_charge.id)
      expect(result_data["invoiceDisplayName"]).to eq("Updated Fixed Charge")
      expect(result_data["units"]).to eq("20")
    end
  end

  context "with properties" do
    let(:input) do
      {
        subscriptionId: subscription.id,
        fixedChargeCode: fixed_charge.code,
        properties: {amount: "150"}
      }
    end

    it "creates a fixed charge override with the given properties" do
      result_data = subject["data"]["updateSubscriptionFixedCharge"]

      override = FixedCharge.find(result_data["id"])
      expect(override.properties).to eq("amount" => "150")
    end

    context "when subscription already has a fixed charge override" do
      let(:overridden_plan) { create(:plan, organization:, parent: plan) }
      let(:subscription) { create(:subscription, organization:, plan: overridden_plan) }
      let(:overridden_fixed_charge) { create(:fixed_charge, plan: overridden_plan, organization:, add_on:, parent: fixed_charge, code: fixed_charge.code) }

      before { overridden_fixed_charge }

      it "updates the existing override properties" do
        result_data = subject["data"]["updateSubscriptionFixedCharge"]

        expect(result_data["id"]).to eq(overridden_fixed_charge.id)
        expect(overridden_fixed_charge.reload.properties).to eq("amount" => "150")
      end
    end
  end

  context "with taxes" do
    let(:tax) { create(:tax, organization:) }
    let(:input) do
      {
        subscriptionId: subscription.id,
        fixedChargeCode: fixed_charge.code,
        invoiceDisplayName: "Taxed Fixed Charge",
        taxCodes: [tax.code]
      }
    end

    it "creates a fixed charge override with taxes" do
      subject

      result_data = subject["data"]["updateSubscriptionFixedCharge"]
      expect(result_data["invoiceDisplayName"]).to eq("Taxed Fixed Charge")
    end
  end
end
