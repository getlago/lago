# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cascade bulk filter updates via Plans::UpdateService", :premium do
  include ScenariosHelper

  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  let(:billable_metric) { create(:billable_metric, organization:, code: "storage") }
  let(:bm_filter) do
    create(:billable_metric_filter, billable_metric:, key: "region", values: %w[us eu asia])
  end

  before { bm_filter }

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

  def bulk_update_charge(parent_plan, parent_charge, filters_payload, **opts)
    update_plan(parent_plan, {
      cascade_updates: true,
      charges: [
        {
          id: parent_charge.id,
          billable_metric_id: parent_charge.billable_metric_id,
          charge_model: parent_charge.charge_model,
          properties: parent_charge.properties,
          filters: filters_payload
        }
      ]
    }, **opts)
  end

  it "enqueues one ChargeFilters::CascadeJob per changed filter (no shared advisory lock)" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]

    expect do
      bulk_update_charge(parent_plan, parent_charge, [
        {
          invoice_display_name: "US region",
          properties: {amount: "15"},
          values: {region: ["us"]}
        },
        {
          invoice_display_name: "EU region",
          properties: {amount: "25"},
          values: {region: ["eu"]}
        }
      ], perform_jobs: false)
    end.to have_enqueued_job(ChargeFilters::CascadeJob).twice
  end

  it "does not enqueue cascade jobs for unchanged filters" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]

    expect do
      bulk_update_charge(parent_plan, parent_charge, [
        {
          invoice_display_name: "US region",
          properties: {amount: "15"}, # only US changes
          values: {region: ["us"]}
        },
        {
          invoice_display_name: "EU region",
          properties: {amount: "20"}, # unchanged
          values: {region: ["eu"]}
        }
      ], perform_jobs: false)
    end.to have_enqueued_job(ChargeFilters::CascadeJob).once
  end

  it "cascades bulk filter updates to children when jobs run" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]

    bulk_update_charge(parent_plan, parent_charge, [
      {
        invoice_display_name: "US region",
        properties: {amount: "15"},
        values: {region: ["us"]}
      },
      {
        invoice_display_name: "EU region",
        properties: {amount: "25"},
        values: {region: ["eu"]}
      }
    ])

    child_filter_us = child_charge.filters.find_by(invoice_display_name: "US region")
    child_filter_eu = child_charge.filters.find_by(invoice_display_name: "EU region")

    expect(child_filter_us.properties).to eq({"amount" => "15"})
    expect(child_filter_eu.properties).to eq({"amount" => "25"})
  end

  it "cascades a new filter added in a bulk update as a 'create' job" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]

    expect(child_charge.filters.count).to eq(2)

    bulk_update_charge(parent_plan, parent_charge, [
      {
        invoice_display_name: "US region",
        properties: {amount: "10"},
        values: {region: ["us"]}
      },
      {
        invoice_display_name: "EU region",
        properties: {amount: "20"},
        values: {region: ["eu"]}
      },
      {
        invoice_display_name: "Asia region",
        properties: {amount: "30"},
        values: {region: ["asia"]}
      }
    ])

    child_charge.reload
    expect(child_charge.filters.count).to eq(3)

    child_filter_asia = child_charge.filters.find_by(invoice_display_name: "Asia region")
    expect(child_filter_asia.properties).to eq({"amount" => "30"})
    expect(child_filter_asia.to_h).to eq({"region" => ["asia"]})
  end

  it "cascades a removed filter in a bulk update as a 'destroy' job" do
    ctx = setup_plan_with_subscription
    parent_plan = ctx[:parent_plan]
    parent_charge = ctx[:parent_charge]
    child_charge = ctx[:child_charge]

    expect(child_charge.filters.count).to eq(2)

    bulk_update_charge(parent_plan, parent_charge, [
      {
        invoice_display_name: "US region",
        properties: {amount: "10"},
        values: {region: ["us"]}
      }
    ])

    child_charge.reload
    expect(child_charge.filters.count).to eq(1)
    expect(child_charge.filters.first.invoice_display_name).to eq("US region")
  end
end
