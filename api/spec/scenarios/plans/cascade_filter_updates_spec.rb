# frozen_string_literal: true

require "rails_helper"

# Tests filter-level cascade for create, update, and destroy operations.
# Each filter operation cascades only that specific filter to child charges
RSpec.describe "Cascade filter updates", :premium do
  include ScenariosHelper

  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  let(:billable_metric) { create(:billable_metric, organization:, code: "storage") }
  let(:bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us eu asia])
  end

  before { bm_filter }

  # Sets up a parent plan with a charge and two filters, a subscription with
  # a charge override, and returns the key objects for assertions.
  def setup_plan_with_subscription
    create_plan({
      name: "Enterprise",
      code: "enterprise",
      interval: "monthly",
      amount_cents: 0,
      amount_currency: "EUR",
      pay_in_advance: false,
      charges: [
        {
          billable_metric_id: billable_metric.id,
          charge_model: "standard",
          code: "storage_charge",
          pay_in_advance: false,
          properties: {amount: "0"},
          filters: [
            {
              invoice_display_name: "US region",
              properties: {amount: "10"},
              values: {region: ["us"]}
            },
            {
              invoice_display_name: "EU region",
              properties: {amount: "20"},
              values: {region: ["eu"]}
            }
          ]
        }
      ]
    })

    parent_plan = organization.plans.find_by(code: "enterprise")
    parent_charge = parent_plan.charges.first

    create_subscription({
      external_customer_id: customer.external_id,
      external_id: "sub_enterprise",
      plan_code: "enterprise"
    })

    subscription = organization.subscriptions.find_by(external_id: "sub_enterprise")

    update_subscription_charge(subscription, "storage_charge", {
      invoice_display_name: "My storage",
      properties: {amount: "0"}
    })

    subscription.reload
    child_charge = subscription.plan.charges.find_by(code: "storage_charge")

    {parent_plan:, parent_charge:, child_charge:}
  end

  it "cascades rapid-fire filter updates independently" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]
    filter_us = parent_charge.filters.find_by(invoice_display_name: "US region")
    filter_eu = parent_charge.filters.find_by(invoice_display_name: "EU region")
    child_filter_us = child_charge.filters.find_by(invoice_display_name: "US region")
    child_filter_eu = child_charge.filters.find_by(invoice_display_name: "EU region")

    # Queue multiple filter updates without executing jobs
    update_plan_charge_filter(
      parent_plan, parent_charge.code, filter_us.id,
      {properties: {amount: "15"}, cascade_updates: true},
      perform_jobs: false
    )

    update_plan_charge_filter(
      parent_plan, parent_charge.code, filter_eu.id,
      {properties: {amount: "25"}, cascade_updates: true},
      perform_jobs: false
    )

    # Child is unchanged before jobs run
    expect(child_filter_us.reload.properties).to eq({"amount" => "10"})
    expect(child_filter_eu.reload.properties).to eq({"amount" => "20"})

    # Each filter update enqueued its own independent CascadeJob
    perform_all_enqueued_jobs

    expect(child_filter_us.reload.properties).to eq({"amount" => "15"})
    expect(child_filter_eu.reload.properties).to eq({"amount" => "25"})
  end

  it "cascades filter creation to child charges" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]

    expect(child_charge.filters.count).to eq(2)

    create_plan_charge_filter(parent_plan, parent_charge.code, {
      invoice_display_name: "Asia region",
      properties: {amount: "30"},
      values: {region: ["asia"]},
      cascade_updates: true
    })

    child_charge.reload
    expect(child_charge.filters.count).to eq(3)

    child_filter_asia = child_charge.filters.find_by(invoice_display_name: "Asia region")
    expect(child_filter_asia.properties).to eq({"amount" => "30"})
    expect(child_filter_asia.to_h).to eq({"region" => ["asia"]})
  end

  it "cascades filter deletion to child charges" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]
    filter_eu = parent_charge.filters.find_by(invoice_display_name: "EU region")

    expect(child_charge.filters.count).to eq(2)

    delete_plan_charge_filter(parent_plan, parent_charge.code, filter_eu.id)

    # Destroy via API doesn't pass cascade_updates through the helper,
    # so cascade manually to test the destroy path
    ChargeFilters::CascadeService.call!(
      charge: parent_charge,
      action: "destroy",
      filter_values: {"region" => ["eu"]}
    )

    child_charge.reload
    expect(child_charge.filters.count).to eq(1)
    expect(child_charge.filters.first.invoice_display_name).to eq("US region")
  end

  it "does not overwrite a customer-customized filter" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]
    filter_us = parent_charge.filters.find_by(invoice_display_name: "US region")
    child_filter_us = child_charge.filters.find_by(invoice_display_name: "US region")

    # Customer customizes the US filter on their subscription
    child_filter_us.update!(properties: {"amount" => "99"})

    # Admin updates the same filter on the parent plan
    update_plan_charge_filter(
      parent_plan, parent_charge.code, filter_us.id,
      {properties: {amount: "15"}, cascade_updates: true}
    )

    # Customer's override is preserved
    expect(child_filter_us.reload.properties).to eq({"amount" => "99"})
  end
end
