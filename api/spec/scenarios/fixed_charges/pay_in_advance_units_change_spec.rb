# frozen_string_literal: true

require "rails_helper"

describe "Pay in advance fixed charge units change mid-period", :premium do
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

  # Fixed charge: $10 per unit, 10 units, pay in advance, not prorated
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

  describe "when units change mid-period with apply_units_immediately: true" do
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    before do
      fixed_charge

      # Create subscription at the start of the month
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

      # Process the initial invoice
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoice with 10 units" do
      expect(subscription.invoices.count).to eq(1)
      initial_invoice = subscription.invoices.first

      expect(initial_invoice.fees.fixed_charge.count).to eq(1)
      fee = initial_invoice.fees.fixed_charge.first

      # 10 units * $10 = $100 = 10000 cents
      expect(fee.units).to eq(10)
      expect(fee.amount_cents).to eq(10_000)

      # Verify invoice total matches sum of fees
      expect(initial_invoice.fees_amount_cents).to eq(initial_invoice.fees.sum(:amount_cents))
      expect(initial_invoice.fees_amount_cents).to eq(10_000)
    end

    context "when decreasing units from 10 to 5" do
      before do
        travel_to subscription_date + 5.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 5,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )

          perform_all_enqueued_jobs
        end
      end

      it "creates a new fixed charge event with units 5" do
        events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
        expect(events.count).to eq(2)
        expect(events.last.units).to eq(5)
      end

      it "generates a zero-amount invoice when units decrease" do
        # After decreasing units, we expect a new invoice with zero amount
        # because we don't refund pay-in-advance fixed charges
        expect(subscription.reload.invoices.count).to eq(2)

        adjustment_invoice = subscription.invoices.order(:created_at).last
        expect(adjustment_invoice.fees.count).to eq(1)
        expect(adjustment_invoice.fees_amount_cents).to eq(0)
      end
    end

    context "when increasing units from 10 to 15" do
      before do
        travel_to subscription_date + 5.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 15,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "creates a new fixed charge event with units 15" do
        events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
        expect(events.count).to eq(2)
        expect(events.last.units).to eq(15)
      end

      it "generates an invoice for the additional units only (delta billing)" do
        # After increasing units from 10 to 15, we expect a new invoice
        # for the 5 additional units only: 5 * $10 = $50 = 5000 cents
        expect(subscription.reload.invoices.count).to eq(2)

        adjustment_invoice = subscription.invoices.order(:created_at).last
        expect(adjustment_invoice.fees.fixed_charge.count).to eq(1)

        fee = adjustment_invoice.fees.fixed_charge.first
        expect(fee.units).to eq(5)  # Only the delta
        expect(fee.amount_cents).to eq(5_000)  # 5 units * $10 = $50

        # Verify invoice total matches sum of fees
        expect(adjustment_invoice.fees_amount_cents).to eq(adjustment_invoice.fees.sum(:amount_cents))
        expect(adjustment_invoice.fees_amount_cents).to eq(5_000)
      end
    end

    context "when decreasing then increasing units (10 -> 5 -> 15)" do
      before do
        # First decrease to 5
        travel_to subscription_date + 5.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 5,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )
          perform_all_enqueued_jobs
        end

        # Then increase to 15
        travel_to subscription_date + 10.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 15,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "creates fixed charge events for each change" do
        events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)
        expect(events.count).to eq(3)
        expect(events.map(&:units)).to eq([10, 5, 15])
      end

      it "generates invoice for delta from originally paid units (not current units)" do
        # After all changes:
        # - Initial: paid for 10 units
        # - Decrease to 5: no refund, so still paid for 10 units
        # - Increase to 15: should charge for 15 - 10 = 5 units only
        invoices = subscription.reload.invoices.order(:created_at)

        # We expect 3 invoices:
        # 1. Initial invoice (10 units, $100)
        # 2. Decrease invoice (0 amount - no refund)
        # 3. Increase invoice (5 units delta, $50)
        expect(invoices.count).to eq(3)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
        expect(initial_invoice.fees.fixed_charge.first.amount_cents).to eq(10_000)
        expect(initial_invoice.fees_amount_cents).to eq(initial_invoice.fees.sum(:amount_cents))
        expect(initial_invoice.fees_amount_cents).to eq(10_000)

        decrease_invoice = invoices.second
        expect(decrease_invoice.fees.count).to eq(1)
        expect(decrease_invoice.fees_amount_cents).to eq(0)

        increase_invoice = invoices.last
        # This is the critical assertion: we should only charge for 5 units (15 - 10),
        # NOT 10 units (15 - 5), because we never refunded when going from 10 to 5
        expect(increase_invoice.fees.fixed_charge.first.units).to eq(5)
        expect(increase_invoice.fees.fixed_charge.first.amount_cents).to eq(5_000)
        expect(increase_invoice.fees_amount_cents).to eq(increase_invoice.fees.sum(:amount_cents))
        expect(increase_invoice.fees_amount_cents).to eq(5_000)
      end
    end

    context "when increasing units multiple times (10 -> 15 -> 20)" do
      before do
        # First increase to 15
        travel_to subscription_date + 5.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 15,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )
          perform_all_enqueued_jobs
        end

        # Then increase to 20
        travel_to subscription_date + 10.days do
          update_plan(
            plan,
            {
              fixed_charges: [{
                id: fixed_charge.id,
                units: 20,
                apply_units_immediately: true,
                properties: {amount: "10"}
              }]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "generates invoices for each delta increase" do
        invoices = subscription.reload.invoices.order(:created_at)

        # We expect 3 invoices:
        # 1. Initial invoice (10 units, $100)
        # 2. First increase invoice (5 units delta: 15 - 10, $50)
        # 3. Second increase invoice (5 units delta: 20 - 15, $50)
        expect(invoices.count).to eq(3)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
        expect(initial_invoice.fees.fixed_charge.first.amount_cents).to eq(10_000)
        expect(initial_invoice.fees_amount_cents).to eq(initial_invoice.fees.sum(:amount_cents))
        expect(initial_invoice.fees_amount_cents).to eq(10_000)

        first_increase_invoice = invoices.second
        expect(first_increase_invoice.fees.fixed_charge.first.units).to eq(5)
        expect(first_increase_invoice.fees.fixed_charge.first.amount_cents).to eq(5_000)
        expect(first_increase_invoice.fees_amount_cents).to eq(first_increase_invoice.fees.sum(:amount_cents))
        expect(first_increase_invoice.fees_amount_cents).to eq(5_000)

        second_increase_invoice = invoices.last
        expect(second_increase_invoice.fees.fixed_charge.first.units).to eq(5)
        expect(second_increase_invoice.fees.fixed_charge.first.amount_cents).to eq(5_000)
        expect(second_increase_invoice.fees_amount_cents).to eq(second_increase_invoice.fees.sum(:amount_cents))
        expect(second_increase_invoice.fees_amount_cents).to eq(5_000)
      end
    end
  end

  describe "when multiple fixed charges are updated at once via plan update" do
    let(:add_on2) { create(:add_on, organization:) }
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    # Second fixed charge: $20 per unit, 5 units, pay in advance
    let(:fixed_charge2) do
      create(
        :fixed_charge,
        plan:,
        add_on: add_on2,
        units: 5,
        properties: {amount: "20"},
        pay_in_advance: true
      )
    end

    before do
      fixed_charge
      fixed_charge2

      # Create subscription at the start of the month
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_multi_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      # Process the initial invoice
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoice with fees for both fixed charges" do
      expect(subscription.invoices.count).to eq(1)
      initial_invoice = subscription.invoices.first

      expect(initial_invoice.fees.fixed_charge.count).to eq(2)

      fee1 = initial_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge)
      fee2 = initial_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge2)

      # First fixed charge: 10 units * $10 = $100
      expect(fee1.units).to eq(10)
      expect(fee1.amount_cents).to eq(10_000)

      # Second fixed charge: 5 units * $20 = $100
      expect(fee2.units).to eq(5)
      expect(fee2.amount_cents).to eq(10_000)

      # Verify invoice total matches sum of fees ($100 + $100 = $200)
      expect(initial_invoice.fees_amount_cents).to eq(initial_invoice.fees.sum(:amount_cents))
      expect(initial_invoice.fees_amount_cents).to eq(20_000)
    end

    context "when both fixed charges are updated via plan update" do
      before do
        travel_to subscription_date + 5.days do
          # Update plan with both fixed charges having apply_units_immediately: true
          update_plan(
            plan,
            {
              fixed_charges: [
                {
                  id: fixed_charge.id,
                  units: 15,
                  apply_units_immediately: true,
                  properties: {amount: "10"}
                },
                {
                  id: fixed_charge2.id,
                  units: 10,
                  apply_units_immediately: true,
                  properties: {amount: "20"}
                }
              ]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "generates a SINGLE invoice with fees for both fixed charge deltas" do
        invoices = subscription.reload.invoices.order(:created_at)

        # We expect 2 invoices:
        # 1. Initial invoice (both fixed charges)
        # 2. ONE invoice with both fixed charges units deltas
        expect(invoices.count).to eq(2)

        batched_invoice = invoices.last
        expect(batched_invoice.fees.count).to eq(2)

        fee1 = batched_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge)
        fee2 = batched_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge2)

        # First fixed charge delta: 15 - 10 = 5 units * $10 = $50
        expect(fee1.units).to eq(5)
        expect(fee1.amount_cents).to eq(5_000)

        # Second fixed charge delta: 10 - 5 = 5 units * $20 = $100
        expect(fee2.units).to eq(5)
        expect(fee2.amount_cents).to eq(10_000)

        # Verify invoice total matches sum of fees ($50 + $100 = $150)
        expect(batched_invoice.fees_amount_cents).to eq(batched_invoice.fees.sum(:amount_cents))
        expect(batched_invoice.fees_amount_cents).to eq(15_000)
      end
    end
  end

  describe "when adding and updating fix charges with apply units immediately" do
    let(:add_on2) { create(:add_on, organization:) }
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    before do
      fixed_charge

      # Create subscription at the start of the month with one fixed charge
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_add_update_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      # Process the initial invoice
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end
    end

    context "when updating existing fixed charge AND adding a new fixed charge" do
      before do
        travel_to subscription_date + 5.days do
          # Update the plan to:
          # 1. Update existing fixed charge from 10 to 15 units
          # 2. Add a new fixed charge with 8 units at $5 each
          update_plan(
            plan,
            {
              fixed_charges: [
                {
                  id: fixed_charge.id,
                  units: 15,
                  apply_units_immediately: true,
                  properties: {amount: "10"}
                },
                {
                  add_on_id: add_on2.id,
                  invoice_display_name: "New Fixed Charge",
                  charge_model: "standard",
                  units: 8,
                  properties: {amount: "5"},
                  pay_in_advance: true,
                  apply_units_immediately: true
                }
              ]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "generates a SINGLE invoice with fees for both updated and new fixed charges" do
        new_fixed_charge = plan.fixed_charges.find_by(add_on: add_on2)
        invoices = subscription.reload.invoices.order(:created_at)

        # We expect 2 invoices:
        # 1. Initial invoice (original fixed charge only)
        # 2. ONE invoice with delta for updated + full for new
        expect(invoices.count).to eq(2)

        combined_invoice = invoices.last
        expect(combined_invoice.fees.count).to eq(2)

        updated_fixed_charge_fee = combined_invoice.fees.fixed_charge.find_by(fixed_charge:)
        new_fixed_charge_fee = combined_invoice.fees.fixed_charge.find_by(fixed_charge: new_fixed_charge)

        # Updated fixed charge: delta only (15 - 10 = 5 units * $10 = $50)
        expect(updated_fixed_charge_fee.units).to eq(5)
        expect(updated_fixed_charge_fee.amount_cents).to eq(5_000)

        # New fixed charge: full amount (8 units * $5 = $40)
        expect(new_fixed_charge_fee.units).to eq(8)
        expect(new_fixed_charge_fee.amount_cents).to eq(4_000)

        # Total: $50 + $40 = $90
        expect(combined_invoice.fees_amount_cents).to eq(combined_invoice.fees.sum(:amount_cents))
        expect(combined_invoice.fees_amount_cents).to eq(9_000)
      end
    end

    context "when only adding a new fixed charge (no updates to existing)" do
      before do
        travel_to subscription_date + 5.days do
          # Add a new fixed charge without updating the existing one
          update_plan(
            plan,
            {
              fixed_charges: [
                {
                  id: fixed_charge.id,
                  units: 10,  # Same as before
                  properties: {amount: "10"}
                },
                {
                  add_on_id: add_on2.id,
                  invoice_display_name: "New Fixed Charge",
                  charge_model: "standard",
                  units: 6,
                  properties: {amount: "15"},
                  pay_in_advance: true,
                  apply_units_immediately: true
                }
              ]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "generates an invoice only for the new fixed charge" do
        new_fixed_charge = plan.fixed_charges.find_by(add_on: add_on2)
        invoices = subscription.reload.invoices.order(:created_at)

        expect(invoices.count).to eq(2)

        new_charge_invoice = invoices.last
        expect(new_charge_invoice.fees.count).to eq(1)

        fee = new_charge_invoice.fees.fixed_charge.first
        expect(fee.fixed_charge).to eq(new_fixed_charge)

        # New fixed charge: 6 units * $15 = $90
        expect(fee.units).to eq(6)
        expect(fee.amount_cents).to eq(9_000)

        expect(new_charge_invoice.fees_amount_cents).to eq(9_000)
      end
    end
  end

  describe "when updating fixed charge with apply changes on next period" do
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    before do
      fixed_charge

      # Create subscription at the start of the month
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_next_period_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      # Process the initial invoice
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end

      travel_to subscription_date + 5.days do
        # Update the fixed charge units WITHOUT apply_units_immediately
        update_plan(
          plan,
          {
            fixed_charges: [{
              id: fixed_charge.id,
              units: 15,
              # No apply_units_immediately - changes apply next period
              properties: {amount: "10"}
            }]
          }
        )
        perform_all_enqueued_jobs
      end
    end

    it "does NOT generate a new invoice mid-period" do
      invoices = subscription.reload.invoices.order(:created_at)

      # Only the initial invoice should exist
      expect(invoices.count).to eq(1)

      initial_invoice = invoices.first
      expect(initial_invoice.fees.fixed_charge.count).to eq(1)
      expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
      expect(initial_invoice.fees_amount_cents).to eq(10_000)
    end

    it "creates a fixed charge event for the updated charge at next billing period" do
      events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:timestamp)

      expect(events.count).to eq(2)
      expect(events.first.units).to eq(10)
      expect(events.first.timestamp).to be < subscription_date.end_of_month
      expect(events.last.units).to eq(15)
      expect(events.last.timestamp).to be > subscription_date.end_of_month
    end
  end

  describe "when adding fixed charge with apply changes on next period" do
    let(:add_on2) { create(:add_on, organization:) }
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    before do
      fixed_charge

      # Create subscription at the start of the month
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_next_period_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar"
          }
        )
      end

      # Process the initial invoice
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end

      travel_to subscription_date + 5.days do
        # Add a new fixed charge without apply_units_immediately
        update_plan(
          plan,
          {
            fixed_charges: [
              {
                id: fixed_charge.id,
                units: 10,  # No change to existing
                properties: {amount: "10"}
              },
              {
                add_on_id: add_on2.id,
                invoice_display_name: "New Fixed Charge",
                charge_model: "standard",
                units: 8,
                properties: {amount: "5"},
                pay_in_advance: true
                # No apply_units_immediately
              }
            ]
          }
        )
        perform_all_enqueued_jobs
      end
    end

    it "does NOT generate a new invoice mid-period" do
      invoices = subscription.reload.invoices.order(:created_at)

      # Only the initial invoice should exist
      expect(invoices.count).to eq(1)
    end

    it "creates a fixed charge event for the new charge at next billing period" do
      new_fixed_charge = plan.fixed_charges.find_by(add_on: add_on2)
      events = FixedChargeEvent.where(subscription:, fixed_charge: new_fixed_charge).order(:timestamp)

      expect(events.count).to eq(1)
      expect(events.first.units).to eq(8)
      # Event should be scheduled for next billing period
      expect(events.first.timestamp).to be > subscription_date.end_of_month
    end
  end

  describe "when updating multiple fixed charges units with children plans" do
    let(:add_on2) { create(:add_on, organization:) }
    let(:subscription_date) { DateTime.new(2024, 3, 1) }

    # Second fixed charge: $20 per unit, 5 units, pay in advance
    let(:fixed_charge2) do
      create(
        :fixed_charge,
        plan:,
        add_on: add_on2,
        units: 5,
        properties: {amount: "20"},
        pay_in_advance: true
      )
    end

    # Parent plan setup
    let(:parent_plan) { plan }
    let(:parent_subscription) { customer.subscriptions.first }

    # Second customer for child subscription
    let(:customer2) { create(:customer, organization:, timezone: "UTC") }
    let(:child_subscription) { customer2.subscriptions.first }

    before do
      fixed_charge
      fixed_charge2

      # Create parent subscription
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_parent_#{customer.external_id}",
            plan_code: parent_plan.code,
            billing_time: "calendar"
          }
        )

        # Create child subscription using plan_overrides (creates a child plan)
        create_subscription(
          {
            external_customer_id: customer2.external_id,
            external_id: "sub_child_#{customer2.external_id}",
            plan_code: parent_plan.code,
            billing_time: "calendar",
            plan_overrides: {
              name: "Child Plan Override",
              amount_cents: 5000
            }
          }
        )
      end

      # Process initial invoices
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoices for both parent and child subscriptions" do
      expect(parent_subscription.invoices.count).to eq(1)
      expect(child_subscription.invoices.count).to eq(1)

      parent_invoice = parent_subscription.invoices.first
      child_invoice = child_subscription.invoices.first

      parent_fixed_charge_fee_1 = parent_invoice.fees.fixed_charge.find_by(fixed_charge:)
      parent_fixed_charge_fee_2 = parent_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge2)

      expect(parent_fixed_charge_fee_1.units).to eq(10)
      expect(parent_fixed_charge_fee_2.units).to eq(5)

      child_fixed_charge_1 = child_subscription.fixed_charges.find_by(parent: fixed_charge)
      child_fixed_charge_2 = child_subscription.fixed_charges.find_by(parent: fixed_charge2)
      child_fixed_charge_fee_1 = child_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge_1)
      child_fixed_charge_fee_2 = child_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge_2)

      expect(child_fixed_charge_fee_1.units).to eq(10)
      expect(child_fixed_charge_fee_2.units).to eq(5)
    end

    context "when parent plan fixed charge is updated with apply_units_immediately and cascade" do
      let(:child_fixed_charge1) { child_subscription.fixed_charges.find_by(parent: fixed_charge) }
      let(:child_fixed_charge2) { child_subscription.fixed_charges.find_by(parent: fixed_charge2) }

      before do
        travel_to subscription_date + 5.days do
          # Update parent plan with cascade
          update_plan(
            parent_plan,
            {
              cascade_updates: true,
              fixed_charges: [
                {
                  id: fixed_charge.id,
                  units: 25,
                  apply_units_immediately: true,
                  properties: {amount: "10"},
                  charge_model: "standard"
                },
                {
                  id: fixed_charge2.id,
                  units: 15,
                  apply_units_immediately: true,
                  properties: {amount: "20"},
                  charge_model: "standard"
                }
              ]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "updates the child fixed charges units" do
        expect(child_fixed_charge1.reload.units).to eq(25)
        expect(child_fixed_charge2.reload.units).to eq(15)
      end

      it "creates fixed charge events for both parent and child subscriptions" do
        # Parent events
        parent_events_1 = FixedChargeEvent.where(subscription: parent_subscription, fixed_charge:).order(:timestamp)
        expect(parent_events_1.count).to eq(2)
        expect(parent_events_1.last.units).to eq(25)

        parent_events_2 = FixedChargeEvent.where(subscription: parent_subscription, fixed_charge: fixed_charge2).order(:timestamp)
        expect(parent_events_2.count).to eq(2)
        expect(parent_events_2.last.units).to eq(15)

        # Child events
        child_events_1 = FixedChargeEvent.where(subscription: child_subscription, fixed_charge: child_fixed_charge1).order(:timestamp)
        expect(child_events_1.count).to eq(2)
        expect(child_events_1.last.units).to eq(25)

        child_events_2 = FixedChargeEvent.where(subscription: child_subscription, fixed_charge: child_fixed_charge2).order(:timestamp)
        expect(child_events_2.count).to eq(2)
        expect(child_events_2.last.units).to eq(15)
      end

      it "generates a single delta invoices for each parent and child subscriptions" do
        # Parent should have 2 invoices (initial + delta for both fixed charges)
        parent_invoices = parent_subscription.reload.invoices.order(:created_at)
        expect(parent_invoices.count).to eq(2)

        parent_delta_invoice = parent_invoices.last
        expect(parent_delta_invoice.fees.count).to eq(2)

        parent_fixed_charge_fee_1 = parent_delta_invoice.fees.fixed_charge.find_by(fixed_charge:)
        parent_fixed_charge_fee_2 = parent_delta_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge2)

        expect(parent_fixed_charge_fee_1.units).to eq(15)  # 25 - 10 = 15
        expect(parent_fixed_charge_fee_1.amount_cents).to eq(15_000)
        expect(parent_fixed_charge_fee_2.units).to eq(10)  # 15 - 5 = 10
        expect(parent_fixed_charge_fee_2.amount_cents).to eq(20_000)

        # Child should also have 2 invoices (initial + delta for both fixed charges)
        child_invoices = child_subscription.reload.invoices.order(:created_at)
        expect(child_invoices.count).to eq(2)

        child_delta_invoice = child_invoices.last
        expect(child_delta_invoice.fees.count).to eq(2)

        child_delta_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge1)
        child_delta_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge2)

        expect(parent_fixed_charge_fee_1.units).to eq(15)  # 25 - 10 = 15
        expect(parent_fixed_charge_fee_1.amount_cents).to eq(15_000)
        expect(parent_fixed_charge_fee_2.units).to eq(10)  # 15 - 5 = 10
        expect(parent_fixed_charge_fee_2.amount_cents).to eq(20_000)
      end
    end

    context "when parent plan fixed charge is updated WITHOUT cascade" do
      before do
        travel_to subscription_date + 5.days do
          # Update parent plan WITHOUT cascade
          update_plan(
            parent_plan,
            {
              cascade_updates: false,
              fixed_charges: [{
                id: fixed_charge.id,
                units: 15,
                apply_units_immediately: true,
                properties: {amount: "10"},
                charge_model: "standard"
              }]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "does NOT update the child fixed charge units" do
        child_fixed_charge1 = child_subscription.fixed_charges.find_by(parent: fixed_charge)

        expect(fixed_charge.reload.units).to eq(15)
        expect(child_fixed_charge1.reload.units).to eq(10) # Unchanged
      end

      it "generates delta invoice only for parent subscription" do
        # Parent should have 2 invoices
        parent_invoices = parent_subscription.reload.invoices.order(:created_at)
        expect(parent_invoices.count).to eq(2)

        # Child should still have only 1 invoice (initial only)
        child_invoices = child_subscription.reload.invoices.order(:created_at)
        expect(child_invoices.count).to eq(1)
      end
    end
  end

  describe "when fixed charge was overridden on subscription creation" do
    let(:subscription_date) { DateTime.new(2024, 3, 1) }
    let(:subscription) { customer.subscriptions.first }

    # Parent plan setup
    let(:parent_plan) { plan }

    before do
      fixed_charge

      travel_to subscription_date do
        # Create child subscription using plan_overrides (creates a child plan)
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_child_#{customer.external_id}",
            plan_code: parent_plan.code,
            billing_time: "calendar",
            plan_overrides: {
              name: "Child Plan Override",
              fixed_charges: [
                {
                  id: fixed_charge.id,
                  units: 50
                }
              ]
            }
          }
        )

        # Process initial invoices
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoice with overridden fixed charge units" do
      expect(subscription.invoices.count).to eq(1)
      initial_invoice = subscription.invoices.first

      expect(initial_invoice.fees.fixed_charge.count).to eq(1)
      fee = initial_invoice.fees.fixed_charge.first

      # 50 units * $10 = $500 = 50000 cents
      expect(fee.units).to eq(50)
      expect(fee.amount_cents).to eq(50_000)

      # Verify invoice total matches sum of fees
      expect(initial_invoice.fees_amount_cents).to eq(50_000)
    end

    context "when parent plan fixed charge is updated with apply_units_immediately and cascade" do
      let(:child_fixed_charge) { subscription.fixed_charges.find_by(parent: fixed_charge) }

      before do
        travel_to subscription_date + 5.days do
          # Update parent plan with cascade
          update_plan(
            parent_plan,
            {
              cascade_updates: true,
              fixed_charges: [{
                id: fixed_charge.id,
                units: 30,
                apply_units_immediately: true,
                properties: {amount: "10"},
                charge_model: "standard"
              }]
            }
          )

          perform_all_enqueued_jobs
        end
      end

      it "does not update the child fixed charge units" do
        expect(child_fixed_charge.reload.units).to eq(50)
      end

      it "does not generate a new invoice" do
        expect(subscription.invoices.count).to eq(1)
      end
    end
  end

  describe "when adding multiple fixed charges with children plans" do
    let(:add_on2) { create(:add_on, organization:) }
    let(:add_on3) { create(:add_on, organization:) }
    let(:subscription_date) { DateTime.new(2024, 3, 1) }

    # Parent plan setup
    let(:parent_plan) { plan }
    let(:parent_subscription) { customer.subscriptions.first }

    # Second customer for child subscription
    let(:customer2) { create(:customer, organization:, timezone: "UTC") }
    let(:child_subscription) { customer2.subscriptions.first }

    before do
      fixed_charge

      # Create parent subscription
      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_parent_#{customer.external_id}",
            plan_code: parent_plan.code,
            billing_time: "calendar"
          }
        )

        # Create child subscription using plan_overrides (creates a child plan)
        create_subscription(
          {
            external_customer_id: customer2.external_id,
            external_id: "sub_child_#{customer2.external_id}",
            plan_code: parent_plan.code,
            billing_time: "calendar",
            plan_overrides: {
              name: "Child Plan Override",
              amount_cents: 5000
            }
          }
        )
      end

      # Process initial invoices
      travel_to subscription_date + 1.minute do
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoices for both parent and child subscriptions" do
      expect(parent_subscription.invoices.count).to eq(1)
      expect(child_subscription.invoices.count).to eq(1)

      parent_invoice = parent_subscription.invoices.first
      child_invoice = child_subscription.invoices.first

      expect(parent_invoice.fees.fixed_charge.count).to eq(1)
      expect(parent_invoice.fees.fixed_charge.first.units).to eq(10)

      expect(child_invoice.fees.fixed_charge.count).to eq(1)
      expect(child_invoice.fees.fixed_charge.first.units).to eq(10)
    end

    context "when update parent plan with new fixed charges with apply_units_immediately and cascade" do
      let(:fixed_charge2) { parent_plan.fixed_charges.find_by(add_on: add_on2) }
      let(:fixed_charge3) { parent_plan.fixed_charges.find_by(add_on: add_on3) }
      let(:child_fixed_charge2) { child_subscription.fixed_charges.find_by(parent: fixed_charge2) }
      let(:child_fixed_charge3) { child_subscription.fixed_charges.find_by(parent: fixed_charge3) }

      before do
        travel_to subscription_date + 5.days do
          # Update parent plan with cascade
          update_plan(
            parent_plan,
            {
              cascade_updates: true,
              fixed_charges: [
                {
                  add_on_id: add_on2.id,
                  invoice_display_name: "New Fixed Charge",
                  charge_model: "standard",
                  units: 8,
                  properties: {amount: "5"},
                  pay_in_advance: true,
                  apply_units_immediately: true
                },
                {
                  add_on_id: add_on3.id,
                  invoice_display_name: "New Fixed Charge 2",
                  charge_model: "standard",
                  units: 33,
                  properties: {amount: "2"},
                  pay_in_advance: true,
                  apply_units_immediately: true
                }
              ]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "updates the child fixed charges units" do
        expect(child_fixed_charge2.reload.units).to eq(8)
        expect(child_fixed_charge3.reload.units).to eq(33)
      end

      it "creates fixed charge events for both parent and child subscriptions" do
        # Parent events
        parent_events_2 = FixedChargeEvent.where(subscription: parent_subscription, fixed_charge: fixed_charge2).order(:timestamp)
        expect(parent_events_2.count).to eq(1)
        expect(parent_events_2.last.units).to eq(8)

        parent_events_3 = FixedChargeEvent.where(subscription: parent_subscription, fixed_charge: fixed_charge3).order(:timestamp)
        expect(parent_events_3.count).to eq(1)
        expect(parent_events_3.last.units).to eq(33)

        # Child events
        child_events_2 = FixedChargeEvent.where(subscription: child_subscription, fixed_charge: child_fixed_charge2).order(:timestamp)
        expect(child_events_2.count).to eq(1)
        expect(child_events_2.last.units).to eq(8)

        child_events_3 = FixedChargeEvent.where(subscription: child_subscription, fixed_charge: child_fixed_charge3).order(:timestamp)
        expect(child_events_3.count).to eq(1)
        expect(child_events_3.last.units).to eq(33)
      end

      it "generates a single delta invoices for each, parent and child subscriptions" do
        # Parent should have 2 invoices (initial + delta for both fixed charges)
        parent_invoices = parent_subscription.reload.invoices.order(:created_at)
        expect(parent_invoices.count).to eq(2)

        parent_delta_invoice = parent_invoices.last
        expect(parent_delta_invoice.fees.count).to eq(2)

        parent_fixed_charge_fee_2 = parent_delta_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge2)
        parent_fixed_charge_fee_3 = parent_delta_invoice.fees.fixed_charge.find_by(fixed_charge: fixed_charge3)

        expect(parent_fixed_charge_fee_2.units).to eq(8)
        expect(parent_fixed_charge_fee_2.amount_cents).to eq(4000)
        expect(parent_fixed_charge_fee_3.units).to eq(33)
        expect(parent_fixed_charge_fee_3.amount_cents).to eq(6600)

        # Child should also have 2 invoices (initial + delta for both fixed charges)
        child_invoices = child_subscription.reload.invoices.order(:created_at)
        expect(child_invoices.count).to eq(2)

        child_delta_invoice = child_invoices.last
        expect(child_delta_invoice.fees.count).to eq(2)

        child_fixed_charge_fee_2 = child_delta_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge2)
        child_fixed_charge_fee_3 = child_delta_invoice.fees.fixed_charge.find_by(fixed_charge: child_fixed_charge3)

        expect(child_fixed_charge_fee_2.units).to eq(8)
        expect(child_fixed_charge_fee_2.amount_cents).to eq(4000)
        expect(child_fixed_charge_fee_3.units).to eq(33)
        expect(child_fixed_charge_fee_3.amount_cents).to eq(6600)
      end
    end

    context "when parent plan fixed charge is created WITHOUT cascade" do
      before do
        travel_to subscription_date + 5.days do
          # Update parent plan WITHOUT cascade
          update_plan(
            parent_plan,
            {
              cascade_updates: false,
              fixed_charges: [{
                add_on_id: add_on2.id,
                invoice_display_name: "New Fixed Charge",
                charge_model: "standard",
                units: 8,
                properties: {amount: "5"},
                pay_in_advance: true,
                apply_units_immediately: true
              }]
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "does NOT update the child fixed charge units" do
        expect(child_subscription.fixed_charges.count).to eq(1)
      end

      it "generates delta invoice only for parent subscription" do
        # Parent should have 2 invoices
        parent_invoices = parent_subscription.reload.invoices.order(:created_at)
        expect(parent_invoices.count).to eq(2)

        # Child should still have only 1 invoice (initial only)
        child_invoices = child_subscription.reload.invoices.order(:created_at)
        expect(child_invoices.count).to eq(1)
      end
    end
  end

  describe "when updating subscription with plan_overrides creates child fixed charge" do
    # Regression test: When a subscription is updated with plan_overrides,
    # it creates a new child plan with new fixed charges (different IDs).
    # The delta billing should correctly find the previous fee from the parent
    # fixed charge, not just by the new fixed charge ID.
    let(:subscription_date) { DateTime.new(2024, 12, 1) }
    let(:subscription) { customer.subscriptions.first }

    # Fixed charge: $10 per unit, 5 units, pay in advance
    let(:parent_fixed_charge) { fixed_charge }

    before do
      parent_fixed_charge

      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_override_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar",
            subscription_at: subscription_date.iso8601
          }
        )
        perform_all_enqueued_jobs
      end
    end

    it "generates initial invoice for 10 units with full period boundaries (Dec 1-31)" do
      expect(subscription.invoices.count).to eq(1)
      initial_invoice = subscription.invoices.first

      expect(initial_invoice.fees.fixed_charge.count).to eq(1)
      fee = initial_invoice.fees.fixed_charge.first

      # 10 units * $10 = $100 = 10000 cents
      expect(fee.units).to eq(10)
      expect(fee.amount_cents).to eq(10_000)

      # Fee boundaries should be Dec 1 - Dec 31 (full period)
      expect(fee.properties["fixed_charges_from_datetime"]).to eq("2024-12-01T00:00:00.000Z")
      expect(fee.properties["fixed_charges_to_datetime"]).to eq("2024-12-31T23:59:59.999Z")
    end

    context "when subscription is updated with plan_overrides to increase units to 15 with apply_units_immediately" do
      before do
        travel_to subscription_date + 1.hour do
          update_subscription(
            subscription,
            {
              plan_overrides: {
                fixed_charges: [{
                  id: parent_fixed_charge.id,
                  units: 15,
                  apply_units_immediately: true,
                  charge_model: "standard",
                  properties: {amount: "10"}
                }]
              }
            }
          )

          perform_all_enqueued_jobs
        end
      end

      it "creates a child plan with overridden fixed charge" do
        child_plan = subscription.reload.plan
        expect(child_plan.parent_id).to eq(plan.id)

        child_fixed_charge = child_plan.fixed_charges.first
        expect(child_fixed_charge.parent_id).to eq(parent_fixed_charge.id)
        expect(child_fixed_charge.units).to eq(15)
      end

      it "creates a fixed charge event for the child fixed charge" do
        child_fixed_charge = subscription.reload.plan.fixed_charges.first
        events = FixedChargeEvent.where(subscription:, fixed_charge: child_fixed_charge).order(:created_at)

        expect(events.count).to eq(1)
        expect(events.first.units).to eq(15)
      end

      it "generates a delta invoice for only 5 units (15 - 10), not 15 units" do
        invoices = subscription.reload.invoices.order(:created_at)

        # Should have 2 invoices:
        # 1. Initial invoice (10 units, $100)
        # 2. Delta invoice (5 units, $50) - NOT 15 units
        expect(invoices.count).to eq(2)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
        expect(initial_invoice.fees.fixed_charge.first.amount_cents).to eq(10_000)

        delta_invoice = invoices.last
        expect(delta_invoice.fees.fixed_charge.count).to eq(1)

        delta_fee = delta_invoice.fees.fixed_charge.first
        # KEY ASSERTION: Should only be 10 units (delta), not 15 units (full amount)
        # The bug is that it was generating 15 units because it couldn't find the
        # previous fee since the fixed charge IDs are different (parent vs child)
        expect(delta_fee.units).to eq(5)  # 15 - 10 = 5
        expect(delta_fee.amount_cents).to eq(5_000)  # 5 * $10 = $50
      end

      it "has correct boundaries on the delta fee (same period as initial)" do
        delta_invoice = subscription.reload.invoices.order(:created_at).last
        delta_fee = delta_invoice.fees.fixed_charge.first

        # Same billing period boundaries as initial fee
        expect(delta_fee.properties["fixed_charges_from_datetime"]).to eq("2024-12-01T00:00:00.000Z")
        expect(delta_fee.properties["fixed_charges_to_datetime"]).to eq("2024-12-31T23:59:59.999Z")
      end
    end

    context "when subscription is updated to decrease units (10 -> 3) via plan_overrides" do
      before do
        travel_to subscription_date + 1.hour do
          update_subscription(
            subscription,
            {
              plan_overrides: {
                fixed_charges: [{
                  id: parent_fixed_charge.id,
                  units: 3,
                  apply_units_immediately: true,
                  charge_model: "standard",
                  properties: {amount: "10"}
                }]
              }
            }
          )

          perform_all_enqueued_jobs
        end
      end

      it "generates a zero-fee invoice for decrease (no refund on pay-in-advance)" do
        invoices = subscription.reload.invoices.order(:created_at)

        # Should have 2 invoices:
        # 1. Initial invoice (10 units, $100)
        # 2. Decrease invoice (0 fee - no refund, no extra charge)
        expect(invoices.count).to eq(2)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)

        # The decrease invoice should NOT have any fees with positive units
        # because we already paid for 10 units and are decreasing to 3
        decrease_invoice = invoices.last
        expect(decrease_invoice.fees.fixed_charge.count).to eq(1)
        expect(decrease_invoice.fees.fixed_charge.first.units).to eq(0)
      end
    end

    context "when subscription is updated twice via plan_overrides (10 -> 3 -> 15)" do
      before do
        # First update: decrease from 10 to 3 (no refund expected)
        travel_to subscription_date + 1.hour do
          update_subscription(
            subscription,
            {
              plan_overrides: {
                fixed_charges: [{
                  id: parent_fixed_charge.id,
                  units: 3,
                  apply_units_immediately: true,
                  charge_model: "standard",
                  properties: {amount: "10"}
                }]
              }
            }
          )

          perform_all_enqueued_jobs
        end

        # Second update: increase from 3 to 15
        # Should only charge for delta from max paid (10), not from current (3)
        travel_to subscription_date + 2.hours do
          # After first override, the subscription has a child plan
          child_fixed_charge = subscription.reload.plan.fixed_charges.first

          update_subscription(
            subscription,
            {
              plan_overrides: {
                fixed_charges: [{
                  id: child_fixed_charge.id,
                  units: 15,
                  apply_units_immediately: true,
                  charge_model: "standard",
                  properties: {amount: "10"}
                }]
              }
            }
          )

          perform_all_enqueued_jobs
        end
      end

      it "generates correct invoices respecting previously paid units" do
        invoices = subscription.reload.invoices.order(:created_at)

        # When fixed properly:
        # - Initial invoice (10 units, $100)
        # - Decrease invoice (0 fee - no refund)
        # - Increase invoice (5 units delta: 15 - 10, NOT 15 - 3)
        #
        # Bug behavior: generates wrong fee amounts because it can't find
        # fees from parent fixed charge when calculating delta
        expect(invoices.count).to eq(3)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
        expect(initial_invoice.fees.fixed_charge.first.amount_cents).to eq(10_000)

        decrease_invoice = invoices.second
        expect(decrease_invoice.fees.count).to eq(1)
        expect(decrease_invoice.fees.first.units).to eq(0)

        # Increase invoice: should charge for 5 units only (15 - 10)
        # NOT 12 units (15 - 3), because we already paid for 10 units
        increase_invoice = invoices.last
        increase_fee = increase_invoice.fees.fixed_charge.first
        expect(increase_fee.units).to eq(5)  # 15 - 10 = 5
        expect(increase_fee.amount_cents).to eq(5_000)
      end
    end
  end

  # Bug repro: hitting the dedicated subscription-scoped endpoint
  # PUT /api/v1/subscriptions/:external_id/fixed_charges/:code with
  # apply_units_immediately: true silently skips the mid-period delta invoice.
  # The plan-level endpoint and the plan_overrides path both dispatch
  # Invoices::CreatePayInAdvanceFixedChargesJob; this one doesn't.
  describe "when updating subscription fixed charge via the dedicated endpoint" do
    let(:subscription_date) { DateTime.new(2024, 12, 1) }
    let(:subscription) { customer.subscriptions.first }

    before do
      fixed_charge

      travel_to subscription_date do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "sub_endpoint_#{customer.external_id}",
            plan_code: plan.code,
            billing_time: "calendar",
            subscription_at: subscription_date.iso8601
          }
        )
        perform_all_enqueued_jobs
      end
    end

    context "when increasing units to 15 with apply_units_immediately: true" do
      before do
        travel_to subscription_date + 1.hour do
          update_subscription_fixed_charge(
            subscription,
            fixed_charge.code,
            {
              units: "15",
              apply_units_immediately: true
            }
          )
          perform_all_enqueued_jobs
        end
      end

      it "writes a per-subscription units override row without cloning the plan" do
        subscription.reload
        expect(subscription.plan).to eq(plan)
        expect(plan.fixed_charges.reload).to contain_exactly(fixed_charge)

        override = Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
        expect(override).to be_present
        expect(override.units).to eq(15)
      end

      it "appends a FixedChargeEvent on the parent fixed_charge with units=15 at the update time" do
        events = FixedChargeEvent.where(subscription:, fixed_charge:).order(:created_at)

        # Two events on the parent fixed_charge:
        #   1. units=10 from subscription creation.
        #   2. units=15 at the update time, emitted by the units-only fast
        #      path on UpdateOrOverrideFixedChargeService.
        expect(events.count).to eq(2)
        update_event = events.last
        expect(update_event.units).to eq(15)
        expect(update_event.timestamp).to be_within(5.seconds).of(subscription_date + 1.hour)
      end

      it "generates a mid-period delta invoice for 5 units (15 - 10)" do
        invoices = subscription.reload.invoices.order(:created_at)

        # Expected behaviour (matches the plan-level endpoint and the
        # plan_overrides path on Subscriptions::UpdateService):
        # 1. Initial invoice (10 units, $100)
        # 2. Mid-period delta invoice (5 units, $50)
        #
        # Current behaviour on main: only the initial invoice exists
        # because UpdateOrOverrideFixedChargeService never dispatches
        # Invoices::CreatePayInAdvanceFixedChargesJob.
        expect(invoices.count).to eq(2)

        initial_invoice = invoices.first
        expect(initial_invoice.fees.fixed_charge.first.units).to eq(10)
        expect(initial_invoice.fees.fixed_charge.first.amount_cents).to eq(10_000)

        delta_invoice = invoices.last
        expect(delta_invoice.fees.fixed_charge.count).to eq(1)

        delta_fee = delta_invoice.fees.fixed_charge.first
        expect(delta_fee.units).to eq(5)
        expect(delta_fee.amount_cents).to eq(5_000)
      end

      it "next regular billing cycle bills the new units (15), not the old (10)" do
        expect {
          travel_to subscription_date + 1.month + 1.minute do
            perform_billing
          end
        }.to change { subscription.reload.invoices.count }.by(1)

        next_period_invoice = subscription.reload.invoices.order(:created_at).last
        next_period_fee = next_period_invoice.fees.fixed_charge.first

        # The stale units=10 event sitting at the next-period boundary
        # (see the FixedChargeEvent assertion above) is what the aggregation
        # reads, so next-cycle billing also defaults to 10 units. The gap
        # is broader than just the missing immediate-billing dispatch —
        # subsequent periods also under-bill.
        expect(next_period_fee.units).to eq(15)
        expect(next_period_fee.amount_cents).to eq(15_000)
      end
    end
  end
end
