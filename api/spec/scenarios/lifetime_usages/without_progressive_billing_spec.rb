# frozen_string_literal: true

require "rails_helper"

describe "Lifetime usage without progressive billing", :premium, :time_travel do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: [], premium_integrations: ["lifetime_usage", "progressive_billing"]) }
  let(:plan) { create(:plan, organization: organization, interval: "monthly", amount_cents: 31_00, pay_in_advance: false) }

  let(:customer) { create(:customer, organization: organization) }
  let(:billable_metric) { create(:billable_metric, organization: organization, field_name: "total", aggregation_type: "sum_agg") }
  let(:charge) { create(:charge, plan: plan, billable_metric: billable_metric, charge_model: "standard", properties: {"amount" => "0.01"}) }
  let(:threshold_amount_cents) { 1000 }

  before do
    charge
  end

  it "calculates lifetime usage without generating invoices" do
    create_subscription(
      {
        external_customer_id: customer.external_id,
        external_id: customer.external_id,
        plan_code: plan.code
      }
    )
    subscription = customer.subscriptions.first

    lifetime_usage = subscription.lifetime_usage
    expect(lifetime_usage).not_to be_nil

    pass_time 4.days

    ingest_event(subscription, billable_metric, 1000000)

    expect(lifetime_usage.reload.current_usage_amount_cents).to eq(1_000_000)
    expect(Invoice.count).to eq(0)

    pass_time 1.day

    ingest_event(subscription, billable_metric, 1000000)
    expect(lifetime_usage.reload.current_usage_amount_cents).to eq(2_000_000)
    expect(Invoice.count).to eq(0)

    pass_time 29.days

    expect(Invoice.count).to eq(1)

    invoice = Invoice.sole

    expect(invoice.total_amount_cents).to eq(31_00 + 2_000_000)
    expect(invoice.invoice_type).to eq("subscription")
  end

  it "calculates lifetime usage and does not issue progressive billing invoices once added to the plan" do
    create_subscription(
      {
        external_customer_id: customer.external_id,
        external_id: customer.external_id,
        plan_code: plan.code
      }
    )
    subscription = customer.subscriptions.first

    lifetime_usage = subscription.lifetime_usage
    expect(lifetime_usage).not_to be_nil

    pass_time 4.days

    ingest_event(subscription, billable_metric, 1000000)

    expect(lifetime_usage.reload.current_usage_amount_cents).to eq(1_000_000)
    expect(Invoice.count).to eq(0)

    pass_time 1.day

    ingest_event(subscription, billable_metric, 1000000)
    expect(lifetime_usage.reload.current_usage_amount_cents).to eq(2_000_000)
    expect(Invoice.count).to eq(0)

    pass_time 29.days

    expect(Invoice.count).to eq(1)

    invoice = Invoice.sole

    expect(invoice.total_amount_cents).to eq(31_00 + 2_000_000)
    expect(invoice.invoice_type).to eq("subscription")

    pass_time 1.day
    update_plan(plan, {usage_thresholds: [
      {
        amount_cents: threshold_amount_cents
      }
    ]})

    pass_time 2.days

    expect(Invoice.count).to eq(1)

    ingest_event(subscription, billable_metric, 1000000)
    expect(lifetime_usage.reload.current_usage_amount_cents).to eq(1_000_000)
    expect(lifetime_usage.reload.invoiced_usage_amount_cents).to eq(2_000_000)
    expect(Invoice.count).to eq(1)
  end
end
