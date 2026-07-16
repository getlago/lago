# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Independent charge and filter management", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "value") }

  let(:region_bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us eu asia])
  end
  let(:tier_bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "tier", values: %w[basic pro enterprise])
  end

  before do
    region_bm_filter
    tier_bm_filter
  end

  describe "Plan level: updating charges and filters" do
    it "produces the same result whether updating plan all-at-once or via independent endpoints" do
      # === APPROACH 1: Create plan with charges and filters all-at-once ===
      create_plan({
        name: "Plan All At Once",
        code: "plan_all_at_once",
        interval: "monthly",
        amount_cents: 10_000,
        amount_currency: "EUR",
        pay_in_advance: false,
        charges: [
          {
            billable_metric_id: billable_metric.id,
            charge_model: "standard",
            code: "all_at_once_charge",
            pay_in_advance: false,
            properties: {amount: "10"},
            filters: [
              {
                invoice_display_name: "US Basic",
                properties: {amount: "5"},
                values: {region: ["us"], tier: ["basic"]}
              },
              {
                invoice_display_name: "EU Pro",
                properties: {amount: "15"},
                values: {region: ["eu"], tier: ["pro"]}
              }
            ]
          }
        ]
      })

      plan_all_at_once = organization.plans.find_by(code: "plan_all_at_once")

      # === APPROACH 2: Create plan, then add charges and filters independently ===
      create_plan({
        name: "Plan Independent",
        code: "plan_independent",
        interval: "monthly",
        amount_cents: 10_000,
        amount_currency: "EUR",
        pay_in_advance: false,
        charges: []
      })

      plan_independent = organization.plans.find_by(code: "plan_independent")

      # Create charge independently
      create_plan_charge(plan_independent, {
        billable_metric_id: billable_metric.id,
        charge_model: "standard",
        code: "independent_charge",
        pay_in_advance: false,
        properties: {amount: "10"}
      })

      plan_independent.reload
      charge = plan_independent.charges.find_by(code: "independent_charge")

      # Create filters independently
      create_plan_charge_filter(plan_independent, charge.code, {
        invoice_display_name: "US Basic",
        properties: {amount: "5"},
        values: {region: ["us"], tier: ["basic"]}
      })

      create_plan_charge_filter(plan_independent, charge.code, {
        invoice_display_name: "EU Pro",
        properties: {amount: "15"},
        values: {region: ["eu"], tier: ["pro"]}
      })

      # === COMPARE RESULTS ===
      plan_all_at_once.reload
      plan_independent.reload

      charge_all_at_once = plan_all_at_once.charges.first
      charge_independent = plan_independent.charges.first

      # Both should have the same structure
      expect(charge_all_at_once.charge_model).to eq(charge_independent.charge_model)
      expect(charge_all_at_once.properties).to eq(charge_independent.properties)
      expect(charge_all_at_once.filters.count).to eq(charge_independent.filters.count)

      # Compare filters by invoice_display_name
      %w[US\ Basic EU\ Pro].each do |filter_name|
        filter_all = charge_all_at_once.filters.find_by(invoice_display_name: filter_name)
        filter_ind = charge_independent.filters.find_by(invoice_display_name: filter_name)

        expect(filter_all.properties).to eq(filter_ind.properties)
        expect(filter_all.to_h).to eq(filter_ind.to_h)
      end
    end

    it "allows updating charges and filters independently with same result as plan update" do
      # Create initial plan with charge and filter
      create_plan({
        name: "Update Test Plan",
        code: "update_test_plan",
        interval: "monthly",
        amount_cents: 10_000,
        amount_currency: "EUR",
        pay_in_advance: false,
        charges: [
          {
            billable_metric_id: billable_metric.id,
            charge_model: "standard",
            code: "test_charge",
            pay_in_advance: false,
            properties: {amount: "10"},
            filters: [
              {
                invoice_display_name: "Original Filter",
                properties: {amount: "5"},
                values: {region: ["us"]}
              }
            ]
          }
        ]
      })

      plan = organization.plans.find_by(code: "update_test_plan")
      charge = plan.charges.first
      filter = charge.filters.first

      # Update charge independently
      update_plan_charge(plan, charge.code, {
        charge_model: "standard",
        properties: {amount: "20"},
        min_amount_cents: 100
      })

      charge.reload
      expect(charge.properties["amount"]).to eq("20")
      expect(charge.min_amount_cents).to eq(100)

      # Update filter independently
      update_plan_charge_filter(plan, charge.code, filter.id, {
        invoice_display_name: "Updated Filter",
        properties: {amount: "25"}
      })

      filter.reload
      expect(filter.invoice_display_name).to eq("Updated Filter")
      expect(filter.properties["amount"]).to eq("25")

      # Add new filter independently
      create_plan_charge_filter(plan, charge.code, {
        invoice_display_name: "New Filter",
        properties: {amount: "30"},
        values: {region: ["eu"]}
      })

      charge.reload
      expect(charge.filters.count).to eq(2)
      expect(charge.filters.pluck(:invoice_display_name)).to match_array(["Updated Filter", "New Filter"])

      # Delete filter independently
      new_filter = charge.filters.find_by(invoice_display_name: "New Filter")
      delete_plan_charge_filter(plan, charge.code, new_filter.id)

      charge.reload
      expect(charge.filters.count).to eq(1)
      expect(charge.filters.first.invoice_display_name).to eq("Updated Filter")
    end
  end

  describe "Subscription level: updating charges and filters with overrides" do
    let(:base_plan) do
      create(:plan, organization:, name: "Base Plan", code: "base_plan", amount_cents: 10_000)
    end
    let(:charge) do
      create(:standard_charge, plan: base_plan, billable_metric:, code: "base_charge", properties: {"amount" => "10"})
    end
    let(:charge_filter) do
      create(:charge_filter, charge:, organization:, invoice_display_name: "Base Filter", properties: {"amount" => "5"}).tap do |filter|
        create(:charge_filter_value, charge_filter: filter, billable_metric_filter: region_bm_filter, values: ["us"], organization:)
      end
    end

    before do
      charge
      charge_filter
    end

    it "produces the same override structure whether updating subscription all-at-once or via independent endpoints" do
      # Create two subscriptions on the same base plan
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_all_at_once",
        plan_code: base_plan.code
      })
      sub_all_at_once = organization.subscriptions.find_by(external_id: "sub_all_at_once")

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_independent",
        plan_code: base_plan.code
      })
      sub_independent = organization.subscriptions.find_by(external_id: "sub_independent")

      # Both should be on the base plan initially
      expect(sub_all_at_once.plan_id).to eq(base_plan.id)
      expect(sub_independent.plan_id).to eq(base_plan.id)

      # === APPROACH 1: Update subscription with charges all-at-once ===
      update_subscription(sub_all_at_once, {
        plan_overrides: {
          charges: [
            {
              id: charge.id,
              invoice_display_name: "Overridden Charge",
              properties: {amount: "50"},
              filters: [
                {
                  invoice_display_name: "Overridden Filter",
                  properties: {amount: "25"},
                  values: {region: ["us"]}
                },
                {
                  invoice_display_name: "New Sub Filter",
                  properties: {amount: "35"},
                  values: {region: ["eu"]}
                }
              ]
            }
          ]
        }
      })

      sub_all_at_once.reload

      # === APPROACH 2: Update subscription via independent endpoints ===
      update_subscription_charge(sub_independent, charge.code, {
        invoice_display_name: "Overridden Charge",
        properties: {amount: "50"},
        filters: [
          {
            invoice_display_name: "Overridden Filter",
            properties: {amount: "25"},
            values: {region: ["us"]}
          }
        ]
      })

      sub_independent.reload

      # Add new filter independently
      create_subscription_charge_filter(sub_independent, charge.code, {
        invoice_display_name: "New Sub Filter",
        properties: {amount: "35"},
        values: {region: ["eu"]}
      })

      sub_independent.reload

      # === COMPARE OVERRIDE STRUCTURES ===
      # Both subscriptions should now have plan overrides
      expect(sub_all_at_once.plan.parent_id).to eq(base_plan.id)
      expect(sub_independent.plan.parent_id).to eq(base_plan.id)

      # Get the overridden charges
      charge_override_1 = sub_all_at_once.plan.charges.find_by(code: charge.code)
      charge_override_2 = sub_independent.plan.charges.find_by(code: charge.code)

      # Both charge overrides should point to the same parent
      expect(charge_override_1.parent_id).to eq(charge.id)
      expect(charge_override_2.parent_id).to eq(charge.id)

      # Both should have the same overridden properties
      expect(charge_override_1.invoice_display_name).to eq(charge_override_2.invoice_display_name)
      expect(charge_override_1.properties).to eq(charge_override_2.properties)

      # Both should have the same number of filters
      expect(charge_override_1.filters.count).to eq(charge_override_2.filters.count)

      # Compare filters by invoice_display_name
      ["Overridden Filter", "New Sub Filter"].each do |filter_name|
        filter_1 = charge_override_1.filters.find_by(invoice_display_name: filter_name)
        filter_2 = charge_override_2.filters.find_by(invoice_display_name: filter_name)

        expect(filter_1).to be_present, "Filter '#{filter_name}' not found in subscription 1"
        expect(filter_2).to be_present, "Filter '#{filter_name}' not found in subscription 2"
        expect(filter_1.properties).to eq(filter_2.properties)
        expect(filter_1.to_h).to eq(filter_2.to_h)
      end

      # Original charge and filter should remain unchanged
      charge.reload
      charge_filter.reload
      expect(charge.properties["amount"]).to eq("10")
      expect(charge_filter.properties["amount"]).to eq("5")
    end

    it "allows updating and deleting subscription filters independently" do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_filter_ops",
        plan_code: base_plan.code
      })
      sub = organization.subscriptions.find_by(external_id: "sub_filter_ops")

      # Update filter via subscription endpoint (creates override)
      update_subscription_charge_filter(sub, charge.code, charge_filter.id, {
        invoice_display_name: "Updated Sub Filter",
        properties: {amount: "99"}
      })

      sub.reload

      # Should have created plan and charge override
      expect(sub.plan.parent_id).to eq(base_plan.id)
      charge_override = sub.plan.charges.find_by(code: charge.code)
      expect(charge_override.parent_id).to eq(charge.id)

      # Filter should be updated on the override
      filter_override = charge_override.filters.first
      expect(filter_override.invoice_display_name).to eq("Updated Sub Filter")
      expect(filter_override.properties["amount"]).to eq("99")

      # Original filter should be unchanged
      charge_filter.reload
      expect(charge_filter.invoice_display_name).to eq("Base Filter")
      expect(charge_filter.properties["amount"]).to eq("5")

      # Add a new filter
      create_subscription_charge_filter(sub, charge.code, {
        invoice_display_name: "Additional Filter",
        properties: {amount: "77"},
        values: {region: ["asia"]}
      })

      charge_override.reload
      expect(charge_override.filters.count).to eq(2)

      # Delete the additional filter
      additional_filter = charge_override.filters.find_by(invoice_display_name: "Additional Filter")
      delete_subscription_charge_filter(sub, charge.code, additional_filter.id)

      charge_override.reload
      expect(charge_override.filters.count).to eq(1)
      expect(charge_override.filters.first.invoice_display_name).to eq("Updated Sub Filter")
    end

    it "deleting a filter from parent creates override and soft-deletes the copied filter" do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_delete_parent",
        plan_code: base_plan.code
      })
      sub = organization.subscriptions.find_by(external_id: "sub_delete_parent")

      # Delete the parent's filter via subscription endpoint
      delete_subscription_charge_filter(sub, charge.code, charge_filter.id)

      sub.reload

      # Should have created override chain
      expect(sub.plan.parent_id).to eq(base_plan.id)
      charge_override = sub.plan.charges.find_by(code: charge.code)
      expect(charge_override.parent_id).to eq(charge.id)

      # The override should have a soft-deleted filter (copied then deleted)
      expect(charge_override.filters.count).to eq(0)
      expect(ChargeFilter.unscoped.where(charge_id: charge_override.id).count).to eq(1)
      deleted_filter = ChargeFilter.unscoped.find_by(charge_id: charge_override.id)
      expect(deleted_filter.deleted_at).to be_present

      # Parent filter should remain unchanged
      charge_filter.reload
      expect(charge_filter.deleted_at).to be_nil
      expect(charge_filter.invoice_display_name).to eq("Base Filter")
    end
  end
end
