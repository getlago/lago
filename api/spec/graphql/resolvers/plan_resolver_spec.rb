# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PlanResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {planId: plan.id}
    )
  end

  let(:required_permission) { "plans:view" }
  let(:query) do
    <<~GQL
      query($planId: ID!) {
        plan(id: $planId) {
          id
          name
          hasActiveSubscriptions
          hasCharges
          hasCustomers
          hasDraftInvoices
          hasFixedCharges
          hasOverriddenPlans
          hasSubscriptions

          customersCount
          subscriptionsCount
          activeSubscriptionsCount
          draftInvoicesCount

          taxes { id rate }
          charges {
            id
            taxes { id rate }
            properties {
              amount
              pricingGroupKeys
              presentationGroupKeys { value options { displayInInvoice } }
              freeUnits
              packageSize
              fixedAmount
              freeUnitsPerEvents
              freeUnitsPerTotalAggregation
              perTransactionMaxAmount
              perTransactionMinAmount
              rate
            }
          }
          fixedCharges {
            id
            taxes { id rate }
            properties { amount }
          }
          minimumCommitment {
            id
            amountCents
            invoiceDisplayName
            taxes { id rate }
          }
          applicableUsageThresholds { amountCents thresholdDisplayName recurring }
          usageThresholds { amountCents thresholdDisplayName recurring }
          entitlements { code name description privileges { code value name valueType } }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }

  let(:add_on) { create(:add_on, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:) }
  let(:usage_threshold) { create(:usage_threshold, plan:, amount_cents: 100) }

  before do
    customer
    minimum_commitment
    usage_threshold
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "plans:view"

  it "returns a single plan" do
    plan_response = result["data"]["plan"]

    expect(plan_response["id"]).to eq(plan.id)
    expect(plan_response["hasCharges"]).to eq(false)
    expect(plan_response["hasCustomers"]).to eq(false)
    expect(plan_response["hasDraftInvoices"]).to eq(false)
    expect(plan_response["hasFixedCharges"]).to eq(false)
    expect(plan_response["hasActiveSubscriptions"]).to eq(false)
    expect(plan_response["hasSubscriptions"]).to eq(false)

    expect(plan_response["usageThresholds"]).to contain_exactly({
      "amountCents" => "100",
      "thresholdDisplayName" => usage_threshold.threshold_display_name,
      "recurring" => false
    })

    expect(plan_response["applicableUsageThresholds"]).to contain_exactly({
      "amountCents" => "100",
      "thresholdDisplayName" => usage_threshold.threshold_display_name,
      "recurring" => false
    })

    expect(plan_response["minimumCommitment"]).to include(
      "id" => minimum_commitment.id,
      "amountCents" => minimum_commitment.amount_cents.to_s,
      "invoiceDisplayName" => minimum_commitment.invoice_display_name,
      "taxes" => []
    )
    expect(plan_response["entitlements"]).to be_empty
  end

  context "when plan has active subscriptions" do
    before do
      create_list(:subscription, 2, customer:, plan:)
    end

    it "returns true for has active subscriptions and subscriptions" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasCustomers"]).to eq(true)
      expect(plan_response["hasActiveSubscriptions"]).to eq(true)
      expect(plan_response["hasSubscriptions"]).to eq(true)

      expect(plan_response["customersCount"]).to eq(1)
      expect(plan_response["subscriptionsCount"]).to eq(2)
    end
  end

  context "when child plan has active subscriptions" do
    before do
      child_plan = create(:plan, organization:, parent: plan)
      create(:subscription, customer:, plan: child_plan)
    end

    it "returns true for has active subscriptions and subscriptions" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasCustomers"]).to eq(true)
      expect(plan_response["hasActiveSubscriptions"]).to eq(true)
      expect(plan_response["hasSubscriptions"]).to eq(true)

      expect(plan_response["customersCount"]).to eq(1)
      expect(plan_response["subscriptionsCount"]).to eq(1)
    end
  end

  context "when plan only has terminated subscriptions" do
    before do
      create(:subscription, :terminated, customer:, plan:)
    end

    it "returns true for has subscriptions but false for active subscriptions" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasCustomers"]).to eq(false)
      expect(plan_response["hasActiveSubscriptions"]).to eq(false)
      expect(plan_response["hasSubscriptions"]).to eq(true)

      expect(plan_response["customersCount"]).to eq(0)
      expect(plan_response["subscriptionsCount"]).to eq(1)
    end
  end

  context "when child plan has terminated subscriptions" do
    before do
      child_plan = create(:plan, organization:, parent: plan)
      create(:subscription, :terminated, customer:, plan: child_plan)
    end

    it "returns true for has subscriptions but false for active subscriptions" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasCustomers"]).to eq(false)
      expect(plan_response["hasActiveSubscriptions"]).to eq(false)
      expect(plan_response["hasSubscriptions"]).to eq(true)

      expect(plan_response["customersCount"]).to eq(0)
      expect(plan_response["subscriptionsCount"]).to eq(1)
    end
  end

  context "when plan has charges" do
    before do
      create(
        :standard_charge,
        billable_metric:,
        plan:,
        properties: {
          amount: "100",
          presentation_group_keys: [
            {"value" => "region", "options" => {"display_in_invoice" => true}}
          ]
        }
      )
    end

    it "returns true for has charges" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasCharges"]).to eq(true)

      expect(plan_response["charges"].sole.dig("properties", "presentationGroupKeys")).to eq([
        {"value" => "region", "options" => {"displayInInvoice" => true}}
      ])
    end
  end

  context "when plan has fixed charges" do
    let(:fixed_charge) { create(:fixed_charge, add_on:, plan:) }

    before { fixed_charge }

    it "returns true for has charges" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasFixedCharges"]).to eq(true)
      expect(plan_response["fixedCharges"].pluck("id")).to match_array([fixed_charge.id])
    end
  end

  context "when plan has draft invoices" do
    before do
      subscription = create(:subscription, customer:, plan:)
      invoice = create(:invoice, :draft, customer:)
      create(:invoice_subscription, subscription:, invoice:)
    end

    it "returns true for has draft invoices" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasDraftInvoices"]).to eq(true)
    end
  end

  context "when child plan has draft invoices" do
    before do
      child_plan = create(:plan, organization:, parent: plan)
      subscription = create(:subscription, :terminated, customer:, plan: child_plan)
      invoice = create(:invoice, :draft, customer:)
      create(:invoice_subscription, subscription:, invoice:)
    end

    it "returns true for has draft invoices" do
      plan_response = result["data"]["plan"]

      expect(plan_response["hasDraftInvoices"]).to eq(true)
    end
  end

  context "when plan is a child plan" do
    subject(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {planId: child_plan.id}
      )
    end

    let(:child_plan) { create(:plan, organization:, parent: plan) }

    it "returns parent usage thresholds as applicable usage thresholds" do
      plan_response = result["data"]["plan"]

      expect(plan_response["usageThresholds"]).to be_empty
      expect(plan_response["applicableUsageThresholds"]).to contain_exactly({
        "amountCents" => "100",
        "thresholdDisplayName" => usage_threshold.threshold_display_name,
        "recurring" => false
      })
    end
  end

  context "when plan has entitlements" do
    let(:feature) { create(:feature, organization:, code: "seats") }
    let(:entitlement) { create(:entitlement, plan:, feature:) }

    before do
      create(:entitlement_value, entitlement:, privilege: create(:privilege, feature:, code: "max", value_type: "integer"), value: 10)

      feature2 = create(:feature, organization:, code: "storage")
      entitlement2 = create(:entitlement, plan:, feature: feature2, created_at: 1.day.ago)
      create(:entitlement_value, entitlement: entitlement2, privilege: create(:privilege, feature: feature2, code: "curr"), value: 2)
    end

    it "returns entitlements" do
      entitlements = result["data"]["plan"]["entitlements"]
      expect(entitlements.first["code"]).to eq "storage"
      expect(entitlements.first["privileges"].sole["value"]).to eq "2"
      expect(entitlements.second["code"]).to eq "seats"
      expect(entitlements.second["privileges"].sole["value"]).to eq "10"
    end

    context "when privilege is boolean" do
      let(:enabled) { create(:privilege, feature:, code: "enabled", value_type: "boolean") }
      let(:beta) { create(:privilege, feature:, code: "beta", value_type: "boolean") }
      let(:enabled_value) { create(:entitlement_value, entitlement:, privilege: enabled, value: true) }
      let(:beta_value) { create(:entitlement_value, entitlement:, privilege: beta, value: false) }

      it "casts boolean values to strings" do
        expect(enabled_value.value).to eq("t")
        expect(beta_value.value).to eq("f")

        result = subject
        feat = result["data"]["plan"]["entitlements"].find { |e| e["code"] == feature.code }
        expect(feat["privileges"].map { |p| p["value"] }).to contain_exactly("10", "true", "false")
      end
    end

    context "when plan is an override" do
      subject(:result) do
        execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {planId: child_plan.id}
        )
      end

      let(:child_plan) { create(:plan, organization:, parent: plan) }

      it "doesn't return entitlements to avoid confusion" do
        expect(result["data"]["plan"]["entitlements"]).to be_empty
      end
    end
  end

  context "when plan is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {planId: "foo"}
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
