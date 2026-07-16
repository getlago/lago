# frozen_string_literal: true

require "rails_helper"

describe "Plan-level fixed_charge update preserves per-subscription unit overrides", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:add_on) { create(:add_on, organization:) }
  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 0,
      interval: "monthly",
      pay_in_advance: true
    )
  end

  # Pay-in-advance, $10 per unit, 10 units by default.
  let(:fixed_charge) do
    create(
      :fixed_charge,
      plan:,
      add_on:,
      units: 10,
      properties: {amount: "10"},
      prorated: false,
      pay_in_advance: true
    )
  end

  let(:customer_a) { create(:customer, organization:, timezone: "UTC", external_id: "cust-a") }
  let(:customer_b) { create(:customer, organization:, timezone: "UTC", external_id: "cust-b") }

  let(:subscription_a) { customer_a.subscriptions.sole }
  let(:subscription_b) { customer_b.subscriptions.sole }

  let(:subscription_date) { DateTime.new(2024, 3, 1) }

  before do
    fixed_charge

    travel_to subscription_date do
      # Sub A: no override (will bill at plan default = 10 units)
      create_subscription({
        external_customer_id: customer_a.external_id,
        external_id: "sub_a",
        plan_code: plan.code,
        billing_time: "calendar"
      })

      # Sub B: units-only plan_overrides → override row written, initial bill at 15 units
      create_subscription({
        external_customer_id: customer_b.external_id,
        external_id: "sub_b",
        plan_code: plan.code,
        billing_time: "calendar",
        plan_overrides: {
          fixed_charges: [{id: fixed_charge.id, units: 15}]
        }
      })
    end

    travel_to subscription_date + 1.minute do
      perform_all_enqueued_jobs
    end
  end

  it "delivers the plan-level update to sub A only; sub B keeps its override on both the mid-period invoice and the next billing cycle" do
    # Initial invoices reflect each subscription's own units
    expect(subscription_a.invoices.sole.fees.fixed_charge.sole.amount_cents).to eq(10_000) # 10 * $10
    expect(subscription_b.invoices.sole.fees.fixed_charge.sole.amount_cents).to eq(15_000) # 15 * $10

    # Plan-level update: units 7 with apply_units_immediately
    travel_to subscription_date + 5.days do
      update_plan(
        plan,
        {
          fixed_charges: [{
            id: fixed_charge.id,
            units: 7,
            apply_units_immediately: true,
            properties: {amount: "10"}
          }]
        }
      )
      perform_all_enqueued_jobs
    end

    # Sub A: new event at 7 + a zero-amount mid-period invoice (paid 10, new is 7 → no refund)
    a_events = FixedChargeEvent.where(subscription: subscription_a, fixed_charge:).order(:created_at)
    expect(a_events.map(&:units)).to eq([10, 7])

    a_invoices = subscription_a.reload.invoices.order(:created_at)
    expect(a_invoices.count).to eq(2)
    expect(a_invoices.last.fees.fixed_charge.sole.amount_cents).to eq(0)

    # Sub B: no new event, no new invoice — override preserved
    b_events = FixedChargeEvent.where(subscription: subscription_b, fixed_charge:).order(:created_at)
    expect(b_events.map(&:units)).to eq([15])
    expect(subscription_b.reload.invoices.count).to eq(1)
    expect(subscription_b.fixed_charge_units_overrides.sole.units).to eq(15)

    # Next billing cycle — sub A bills at 7, sub B bills at 15
    travel_to subscription_date.next_month do
      BillSubscriptionJob.perform_now([subscription_a], Time.current, invoicing_reason: :subscription_periodic)
      BillSubscriptionJob.perform_now([subscription_b], Time.current, invoicing_reason: :subscription_periodic)
      perform_all_enqueued_jobs
    end

    next_cycle_invoice_a = subscription_a.reload.invoices.order(:created_at).last
    expect(next_cycle_invoice_a.fees.fixed_charge.sole).to have_attributes(
      units: 7,
      amount_cents: 7_000
    )

    next_cycle_invoice_b = subscription_b.reload.invoices.order(:created_at).last
    expect(next_cycle_invoice_b.fees.fixed_charge.sole).to have_attributes(
      units: 15,
      amount_cents: 15_000
    )
  end
end
