# frozen_string_literal: true

require "rails_helper"

describe "Subscription fixed charge units override via subscription endpoint", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:, timezone: "UTC") }
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

  let(:subscription_date) { DateTime.new(2024, 3, 1) }
  let(:subscription) { customer.subscriptions.first }

  before do
    fixed_charge

    travel_to subscription_date do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: "sub_#{customer.external_id}",
          plan_code: plan.code,
          billing_time: "calendar"
        }
      )
    end

    travel_to subscription_date + 1.minute do
      perform_all_enqueued_jobs
    end
  end

  it "records the override row, skips plan/fixed_charge override creation, and emits an event with the override units" do
    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {
          units: 15,
          apply_units_immediately: true
        }
      )

      perform_all_enqueued_jobs
    end

    expect(subscription.reload.plan_id).to eq(plan.id)
    expect(Plan.where(parent_id: plan.id)).to be_empty
    expect(FixedCharge.where(parent_id: fixed_charge.id)).to be_empty

    override = subscription.fixed_charge_units_overrides.sole
    expect(override.fixed_charge).to eq(fixed_charge)
    expect(override.units).to eq(15)

    events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
    expect(events.count).to eq(2)
    expect(events.last.units).to eq(15)
  end

  it "promotes an existing units override row onto the plan override when a subsequent non-units change arrives" do
    tax = create(:tax, organization:)

    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {units: 15}
      )
      perform_all_enqueued_jobs
    end

    expect(subscription.fixed_charge_units_overrides.kept.count).to eq(1)

    travel_to subscription_date + 10.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {units: 20, tax_codes: [tax.code]}
      )
      perform_all_enqueued_jobs
    end

    subscription.reload
    overridden_plan = subscription.plan
    expect(overridden_plan.parent_id).to eq(plan.id)

    overridden_fixed_charge = overridden_plan.fixed_charges.find_sole_by(parent_id: fixed_charge.id)
    expect(overridden_fixed_charge.units).to eq(20)
    expect(overridden_fixed_charge.taxes).to include(tax)

    expect(subscription.fixed_charge_units_overrides.kept).to be_empty
  end

  it "issues a zero-amount mid-period invoice when units decrease and never refunds" do
    expect(subscription.invoices.count).to eq(1)
    expect(subscription.invoices.first.fees.fixed_charge.sole.amount_cents).to eq(10_000)

    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {units: 5, apply_units_immediately: true}
      )
      perform_all_enqueued_jobs
    end

    invoices = subscription.reload.invoices.order(:created_at)
    expect(invoices.count).to eq(2)

    decrease_invoice = invoices.last
    expect(decrease_invoice.fees.fixed_charge.sole.amount_cents).to eq(0)
    expect(decrease_invoice.fees_amount_cents).to eq(0)

    override = subscription.fixed_charge_units_overrides.sole
    expect(override.units).to eq(5)

    events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
    expect(events.map(&:units)).to eq([10, 5])
  end

  it "bills the diff from the highest previously-paid value across a 10 → 5 → 15 sequence" do
    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(subscription, fixed_charge.code, {units: 5, apply_units_immediately: true})
      perform_all_enqueued_jobs
    end

    travel_to subscription_date + 10.days do
      update_subscription_fixed_charge(subscription, fixed_charge.code, {units: 15, apply_units_immediately: true})
      perform_all_enqueued_jobs
    end

    invoices = subscription.reload.invoices.order(:created_at)
    expect(invoices.map { |i| i.fees.fixed_charge.sum(:amount_cents) }).to eq([10_000, 0, 5_000])

    override = subscription.fixed_charge_units_overrides.sole
    expect(override.units).to eq(15)

    events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
    expect(events.map(&:units)).to eq([10, 5, 15])
  end

  it "accepts a zero-units override and bills nothing for the rest of the period" do
    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {units: 0, apply_units_immediately: true}
      )
      perform_all_enqueued_jobs
    end

    override = subscription.fixed_charge_units_overrides.sole
    expect(override.units).to eq(0)

    events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
    expect(events.last.units).to eq(0)

    invoices = subscription.reload.invoices.order(:created_at)
    expect(invoices.count).to eq(2)
    expect(invoices.last.fees.fixed_charge.sole.amount_cents).to eq(0)
  end

  it "refuses the units-only branch when the subscription is on an overridden plan and falls through" do
    overridden_plan = create(:plan, organization:, parent: plan, amount_cents: 0, interval: "monthly", pay_in_advance: true)
    create(:fixed_charge, plan: overridden_plan, add_on:, parent: fixed_charge, code: fixed_charge.code,
      units: 10, properties: {amount: "10"}, prorated: false, pay_in_advance: true)
    subscription.update!(plan: overridden_plan)

    travel_to subscription_date + 5.days do
      update_subscription_fixed_charge(
        subscription,
        fixed_charge.code,
        {units: 20, apply_units_immediately: true}
      )
      perform_all_enqueued_jobs
    end

    expect(subscription.reload.fixed_charge_units_overrides.kept).to be_empty
    expect(subscription.plan).to eq(overridden_plan)
    expect(overridden_plan.fixed_charges.find_by(parent_id: fixed_charge.id).units).to eq(20)
  end
end
