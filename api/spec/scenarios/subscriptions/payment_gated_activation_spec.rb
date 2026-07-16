# frozen_string_literal: true

require "rails_helper"

describe "Payment Gated Subscription Activation Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:stripe_customer) { create(:stripe_customer, payment_provider: stripe_provider, customer:) }
  let(:payment_method) { create(:payment_method, customer:) }
  let(:payment_intent_id) { "pi_#{SecureRandom.hex(12)}" }

  let(:plan) do
    create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000)
  end

  let(:subscription_params) do
    {
      external_customer_id: customer.external_id,
      external_id: "gated-sub-#{SecureRandom.hex(4)}",
      plan_code: plan.code,
      billing_time: "calendar",
      activation_rules: [{type: "payment", timeout_hours: 48}]
    }
  end

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: 0)
    customer.update!(payment_provider: :stripe, payment_provider_code: stripe_provider.code)
    stripe_customer
    payment_method

    # Stub Stripe to return processing — payment stays pending, subscription remains incomplete
    allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
      .to receive(:create_payment_intent)
      .and_return(
        Stripe::PaymentIntent.construct_from(
          id: payment_intent_id,
          status: "processing",
          amount: 1000,
          currency: "eur"
        )
      )

    # On activation the finalized invoice number is pushed back to the PSP via
    # UpdatePaymentReferenceJob. The service ignores the return value; this stub
    # only prevents a real Stripe API call in the success scenarios.
    allow(::Stripe::PaymentIntent).to receive(:update).and_return(
      Stripe::PaymentIntent.construct_from(
        id: payment_intent_id,
        object: "payment_intent",
        status: "succeeded",
        amount: 1000,
        currency: "eur"
      )
    )
  end

  def simulate_stripe_webhook(status:, invoice: nil)
    payment = (invoice&.payments || Payment).order(created_at: :desc).first
    payment.update!(provider_payment_id: payment_intent_id)

    # Stub payment method retrieval triggered by SetPaymentMethodAndCreateReceiptJob
    stub_request(:get, %r{https://api.stripe.com/v1/payment_methods/.*})
      .and_return(status: 200, body: {id: "pm_test", object: "payment_method", type: "card"}.to_json)

    event_type = (status == "succeeded") ? "payment_intent.succeeded" : "payment_intent.payment_failed"

    PaymentProviders::Stripe::HandleEventService.call!(
      organization:,
      event_json: {
        id: "evt_#{SecureRandom.hex(10)}",
        object: "event",
        type: event_type,
        data: {
          object: {
            id: payment_intent_id,
            object: "payment_intent",
            status: status.to_s,
            payment_method: "pm_test",
            metadata: {
              lago_invoice_id: payment.payable_id,
              lago_customer_id: customer.id
            }
          }
        }
      }.to_json
    )
    perform_all_enqueued_jobs
  end

  def update_fixed_charge_units(fixed_charge, units, timestamp:, apply_units_immediately: true)
    FixedCharges::UpdateService.call!(
      fixed_charge:,
      params: {units:, charge_model: "standard", properties: {amount: "10"}, apply_units_immediately:},
      timestamp: timestamp.to_i
    )
    perform_all_enqueued_jobs
  end

  def create_fixed_charge(plan, units, timestamp:, apply_units_immediately: true)
    add_on = create(:add_on, organization:)

    result = FixedCharges::CreateService.call!(
      plan:,
      params: {
        add_on_id: add_on.id,
        code: FixedCharges::GenerateCodeService.call(plan:, add_on:).code,
        invoice_display_name: "Extra seats",
        charge_model: "standard",
        units:,
        properties: {amount: "10"},
        pay_in_advance: true,
        apply_units_immediately:
      },
      timestamp: timestamp.to_i
    )
    perform_all_enqueued_jobs
    result.fixed_charge
  end

  describe "new subscription with payment successful" do
    it "creates incomplete subscription, then activates on payment success" do
      # Stage 1: Create subscription — goes incomplete, invoice open
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.started_at).to be_present
      expect(subscription.activated_at).to be_nil
      expect(subscription.activation_rules.sole).to be_pending

      invoice = subscription.invoices.sole
      expect(invoice).to be_open
      expect(invoice.fees.subscription.count).to eq(1)

      # Stage 2: Stripe webhook — payment succeeded
      simulate_stripe_webhook(status: "succeeded")

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.activated_at).to be_present
      expect(subscription.activation_rules.sole).to be_satisfied

      expect(invoice.reload).to be_finalized
      expect(invoice.number).not_to include("DRAFT")
    end
  end

  describe "payment failure: subscription canceled" do
    it "creates incomplete subscription, then cancels on payment failure" do
      # Stage 1: Create subscription — goes incomplete
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete

      invoice = subscription.invoices.sole
      expect(invoice).to be_open

      # Stage 2: Stripe webhook — payment failed
      simulate_stripe_webhook(status: "failed")

      subscription.reload
      expect(subscription).to be_canceled
      expect(subscription.cancellation_reason).to eq("payment_failed")
      expect(subscription.activated_at).to be_nil
      expect(subscription.activation_rules.sole).to be_failed

      expect(invoice.reload).to be_closed
    end

    context "with consumed coupon, credit note, and wallet credits" do
      let(:coupon) do
        create(:coupon, organization:, coupon_type: :fixed_amount,
          amount_cents: 10, amount_currency: "EUR", frequency: :once)
      end
      let(:applied_coupon) do
        create(:applied_coupon, customer:, coupon:, organization:,
          amount_cents: 10, amount_currency: "EUR", frequency: :once, status: :active)
      end
      let(:source_invoice) do
        create(:invoice, customer:, organization:, status: :finalized, currency: "EUR")
      end
      let(:credit_note) do
        create(:credit_note, customer:, organization:, invoice: source_invoice,
          credit_status: :available,
          total_amount_cents: 10, total_amount_currency: "EUR",
          credit_amount_cents: 10, credit_amount_currency: "EUR",
          balance_amount_cents: 10, balance_amount_currency: "EUR")
      end
      let(:wallet) do
        create(:wallet, :with_inbound_transaction, customer:, organization:, currency: "EUR",
          balance_cents: 10, credits_balance: 0.1, rate_amount: 1)
      end

      before do
        applied_coupon
        credit_note
        wallet
      end

      it "restores the coupon, credit note balance, and wallet credits when payment fails" do
        create_subscription(subscription_params)
        perform_all_enqueued_jobs

        invoice = customer.subscriptions.sole.invoices.sole
        expect(invoice).to be_open

        # Resources consumed by the gated invoice
        expect(applied_coupon.reload).to be_terminated
        expect(credit_note.reload.balance_amount_cents).to eq(0)
        expect(credit_note).to be_consumed
        expect(wallet.reload.balance_cents).to eq(0)

        simulate_stripe_webhook(status: "failed")

        expect(invoice.reload).to be_closed

        # Resources restored after the gated invoice was closed
        expect(applied_coupon.reload).to be_active
        expect(applied_coupon.remaining_amount).to eq(10)
        expect(credit_note.reload.balance_amount_cents).to eq(10)
        expect(credit_note).to be_available
        expect(wallet.reload.balance_cents).to eq(10)
        expect(wallet.wallet_transactions.inbound.where(voided_invoice_id: invoice.id)).to exist
      end

      context "when the credit note is voided" do
        let(:credit_note) do
          create(:credit_note, customer:, organization:, invoice: source_invoice,
            credit_status: :voided,
            total_amount_cents: 10, total_amount_currency: "EUR",
            credit_amount_cents: 10, credit_amount_currency: "EUR",
            balance_amount_cents: 10, balance_amount_currency: "EUR")
        end

        it "leaves the voided credit note untouched when payment fails" do
          create_subscription(subscription_params)
          perform_all_enqueued_jobs

          simulate_stripe_webhook(status: "failed")

          invoice = customer.subscriptions.sole.invoices.sole

          expect(invoice.reload).to be_closed
          expect(credit_note.reload).to be_voided
          expect(credit_note.balance_amount_cents).to eq(10)
        end
      end

      context "when the wallet is terminated" do
        let(:wallet) do
          create(:wallet, :terminated, customer:, organization:, currency: "EUR",
            balance_cents: 10, credits_balance: 0.1, rate_amount: 1)
        end

        it "leaves the terminated wallet untouched when payment fails" do
          create_subscription(subscription_params)
          perform_all_enqueued_jobs

          simulate_stripe_webhook(status: "failed")

          invoice = customer.subscriptions.sole.invoices.sole

          expect(invoice.reload).to be_closed
          expect(wallet.reload).to be_terminated
          expect(wallet.balance_cents).to eq(10)
          expect(wallet.wallet_transactions.inbound.where(voided_invoice_id: invoice.id)).not_to exist
        end
      end
    end
  end

  describe "backdated subscription: rules ignored" do
    it "activates immediately without evaluating rules" do
      params = subscription_params.merge(subscription_at: 5.days.ago.iso8601)

      create_subscription(params)

      subscription = customer.subscriptions.sole
      expect(subscription).to be_active
      expect(subscription.activation_rules.count).to eq(0)
      expect(subscription.invoices).to be_empty
    end
  end

  describe "with trial period" do
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000, trial_period: 30)
    end

    context "when plan has no pay-in-advance fixed charges" do
      it "activates immediately because there is nothing to collect" do
        create_subscription(subscription_params)
        perform_all_enqueued_jobs

        subscription = customer.subscriptions.sole
        expect(subscription).to be_active
        expect(subscription.activation_rules.sole).to be_not_applicable
        expect(subscription.invoices).to be_empty
      end
    end

    context "when plan has pay-in-advance fixed charges" do
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

      it "gates on the fixed charge invoice" do
        create_subscription(subscription_params)
        perform_all_enqueued_jobs

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.activation_rules.sole).to be_pending
      end
    end
  end

  describe "zero-amount gated invoice (no charge to collect)" do
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 0)
    end

    it "marks the rule satisfied and activates without going through the payment chain" do
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_active
      expect(subscription.activation_rules.sole).to be_satisfied

      invoice = subscription.invoices.sole
      expect(invoice).to be_finalized
      expect(invoice.total_amount_cents).to eq(0)
      expect(invoice.payment_status).to eq("succeeded")
    end
  end

  describe "pay-in-arrears plan with pay-in-advance fixed charges" do
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: false, amount_cents: 1000)
    end
    let(:add_on) { create(:add_on, organization:) }

    before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

    it "gates on the fixed charge only invoice" do
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.activation_rules.sole).to be_pending

      invoice = subscription.invoices.sole
      expect(invoice).to be_open
      expect(invoice.fees.fixed_charge.count).to be_positive
      expect(invoice.fees.subscription.count).to eq(0)
    end
  end

  describe "fixed-charge delta catch-up on activation" do
    let(:add_on) { create(:add_on, organization:) }
    let(:fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
    end

    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}", status: "processing", amount: 1000, currency: "eur"
          )
        end
    end

    it "bills a mid-incomplete unit increase applied immediately as a delta invoice on activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap: units 10 -> 15. The event is emitted for the incomplete sub but not billed yet.
      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10))
      expect(subscription.invoices.count).to eq(1)

      # Payment succeeds within the same period -> activation bills the 5-unit delta.
      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      delta_invoice = subscription.invoices.order(:created_at).last
      expect(delta_invoice.fees.fixed_charge.count).to eq(1)
      expect(delta_invoice.fees.fixed_charge.sole.units).to eq(5)
    end

    it "bills one delta invoice per distinct timestamp of unit increases applied immediately" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete

      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10))
      update_fixed_charge_units(fixed_charge, 20, timestamp: Time.zone.local(2026, 3, 15, 10))
      expect(subscription.invoices.count).to eq(1)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(3)
    end

    it "documents a mid-incomplete unit reduction applied immediately with a zero-amount invoice (no refund)" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap: units 10 -> 5. Pay-in-advance is never refunded.
      update_fixed_charge_units(fixed_charge, 5, timestamp: Time.zone.local(2026, 3, 10, 10))
      expect(subscription.invoices.count).to eq(1)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      delta_invoice = subscription.invoices.order(:created_at).last
      expect(delta_invoice).to be_finalized
      expect(delta_invoice.total_amount_cents).to eq(0)
      expect(delta_invoice.fees.fixed_charge.sole.units).to eq(0)
    end

    it "bills a unit change scheduled for the next billing period through the regular clock when activation happens within the gated period" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole

      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10), apply_units_immediately: false)

      # Payment succeeds within the gated period: nothing to catch up.
      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(1)

      # The regular billing run at the boundary picks up the scheduled units.
      travel_to(Time.zone.local(2026, 4, 1, 1)) { perform_billing }

      expect(subscription.invoices.count).to eq(2)
      periodic_invoice = subscription.invoices.order(:created_at).last
      expect(periodic_invoice.fees.fixed_charge.sole.units).to eq(15)
    end

    it "bills a fixed charge added mid-incomplete with units applied immediately as a delta invoice on activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap: a brand-new pay-in-advance fixed charge is added to the gated plan.
      new_fixed_charge = create_fixed_charge(plan, 3, timestamp: Time.zone.local(2026, 3, 10, 10))
      expect(subscription.invoices.count).to eq(1)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      delta_fee = subscription.invoices.order(:created_at).last.fees.fixed_charge.sole
      expect(delta_fee.fixed_charge).to eq(new_fixed_charge)
      expect(delta_fee.units).to eq(3)
    end

    it "bills a fixed charge added mid-incomplete with units scheduled for the next billing period through the regular clock" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete

      # Mid-gap: the new charge is scheduled, so its event lands at the next period start (April 1).
      new_fixed_charge = create_fixed_charge(plan, 3, timestamp: Time.zone.local(2026, 3, 10, 10), apply_units_immediately: false)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(1)

      # The regular billing run at the boundary bills the new charge.
      travel_to(Time.zone.local(2026, 4, 1, 1)) { perform_billing }

      expect(subscription.invoices.count).to eq(2)
      periodic_invoice = subscription.invoices.order(:created_at).last
      expect(periodic_invoice.fees.fixed_charge.find_by(fixed_charge: new_fixed_charge).units).to eq(3)
    end
  end

  describe "cascaded plan update with gated subscription on a child plan", :premium do
    let(:add_on) { create(:add_on, organization:) }
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000) do |plan|
        create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
      end
    end
    let(:parent_fixed_charge) { plan.fixed_charges.sole }

    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}", status: "processing", amount: 1000, currency: "eur"
          )
        end
    end

    # FixedCharges::CascadePlanUpdateJob only dispatches to child plans with active
    # or pending subscriptions, so a child plan whose only subscription is incomplete
    # is skipped entirely: no fixed-charge update, no event, no delta on activation.
    # This documents the current behavior; the fix is tracked separately.
    it "does not cascade the unit change to a child plan whose only subscription is incomplete" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        parent_fixed_charge
        create_subscription(subscription_params.merge(plan_overrides: {name: "Child plan", amount_cents: 1500}))
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.plan.parent).to eq(plan)

      child_fixed_charge = subscription.plan.fixed_charges.sole
      expect(child_fixed_charge.parent).to eq(parent_fixed_charge)

      # Mid-gap: the parent plan update cascades, but the child plan is skipped.
      travel_to(Time.zone.local(2026, 3, 10, 10)) do
        update_plan(
          plan,
          {
            cascade_updates: true,
            fixed_charges: [
              {
                id: parent_fixed_charge.id,
                units: 15,
                apply_units_immediately: true,
                properties: {amount: "10"},
                charge_model: "standard"
              }
            ]
          }
        )
        perform_all_enqueued_jobs
      end

      expect(child_fixed_charge.reload.units).to eq(10)
      expect(subscription.fixed_charge_events.count).to eq(1)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(1)
    end
  end

  describe "per-subscription fixed-charge override while incomplete", :premium do
    let(:add_on) { create(:add_on, organization:) }
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000) do |plan|
        create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
      end
    end
    let(:fixed_charge) { plan.fixed_charges.sole }

    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}", status: "processing", amount: 1000, currency: "eur"
          )
        end
    end

    it "bills an override unit increase applied immediately as a delta invoice on activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap: the fixed charge units are overridden for this subscription only.
      travel_to(Time.zone.local(2026, 3, 10, 10)) do
        Subscriptions::UpdateOrOverrideFixedChargeService.call!(
          subscription:,
          fixed_charge:,
          params: {units: 15, apply_units_immediately: true}
        )
        perform_all_enqueued_jobs
      end

      subscription.reload
      expect(subscription.plan).to eq(plan)

      override = Subscription::FixedChargeUnitsOverride.find_by(subscription:, fixed_charge:)
      expect(override.units).to eq(15)
      expect(subscription.invoices.count).to eq(1)

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      delta_fee = subscription.invoices.order(:created_at).last.fees.fixed_charge.sole
      expect(delta_fee.fixed_charge).to eq(fixed_charge)
      expect(delta_fee.units).to eq(5)
    end
  end

  describe "cross-period billing catch-up on activation" do
    let(:add_on) { create(:add_on, organization:) }
    let(:fixed_charge) do
      create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
    end
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {amount: "5"}) }

    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}", status: "processing", amount: 1000, currency: "eur"
          )
        end
    end

    def ingest_usage_event(subscription, timestamp:)
      travel_to(timestamp) do
        create_event(
          {
            transaction_id: SecureRandom.uuid,
            external_subscription_id: subscription.external_id,
            code: billable_metric.code,
            properties: {billable_metric.field_name => 1}
          }
        )
      end
    end

    it "bills a unit change scheduled for the next billing period through the missed-period invoice on cross-period activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap scheduled change: the event is stamped at the next period start (April 1).
      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10), apply_units_immediately: false)

      # Payment succeeds after the period rolled over: the scheduled event is billed
      # by the replayed April periodic invoice.
      travel_to(Time.zone.local(2026, 4, 3, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      periodic_invoice = subscription.invoices.order(:created_at).last
      expect(periodic_invoice).to be_finalized

      billed_period = periodic_invoice.invoice_subscriptions.sole
      expect(billed_period.invoicing_reason).to eq("subscription_periodic")
      expect(billed_period.from_datetime.to_date).to eq(Date.new(2026, 4, 1))
      expect(billed_period.to_datetime.to_date).to eq(Date.new(2026, 4, 30))

      expect(periodic_invoice.fees.subscription.sole.amount_cents).to eq(1000)

      fixed_charge_fee = periodic_invoice.fees.fixed_charge.sole
      expect(fixed_charge_fee.units).to eq(15)
      expect(fixed_charge_fee.amount_cents).to eq(15_000)

      expect(periodic_invoice.total_amount_cents).to eq(16_000)
    end

    it "bills a fixed charge created with units scheduled for the next billing period through the missed-period invoice on cross-period activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.invoices.count).to eq(1)

      # Mid-gap scheduled creation: the event is stamped at the next period start (April 1).
      new_fixed_charge = create_fixed_charge(plan, 3, timestamp: Time.zone.local(2026, 3, 10, 10), apply_units_immediately: false)

      # Payment succeeds after the period rolled over: the scheduled event is billed
      # by the replayed April periodic invoice.
      travel_to(Time.zone.local(2026, 4, 3, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(2)

      periodic_invoice = subscription.invoices.order(:created_at).last
      expect(periodic_invoice).to be_finalized

      billed_period = periodic_invoice.invoice_subscriptions.sole
      expect(billed_period.invoicing_reason).to eq("subscription_periodic")
      expect(billed_period.from_datetime.to_date).to eq(Date.new(2026, 4, 1))
      expect(billed_period.to_datetime.to_date).to eq(Date.new(2026, 4, 30))

      expect(periodic_invoice.fees.subscription.sole.amount_cents).to eq(1000)

      new_fixed_charge_fee = periodic_invoice.fees.fixed_charge.find_by(fixed_charge: new_fixed_charge)
      expect(new_fixed_charge_fee.units).to eq(3)
      expect(new_fixed_charge_fee.amount_cents).to eq(3000)

      original_fixed_charge_fee = periodic_invoice.fees.fixed_charge.find_by(fixed_charge:)
      expect(original_fixed_charge_fee.units).to eq(10)
      expect(original_fixed_charge_fee.amount_cents).to eq(10_000)

      expect(periodic_invoice.total_amount_cents).to eq(14_000)
    end

    it "replays one periodic invoice per missed period without duplicating on retry" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        fixed_charge
        create_subscription(subscription_params)
        perform_all_enqueued_jobs
      end

      subscription = customer.subscriptions.sole
      gated_invoice = subscription.invoices.sole

      # Payment succeeds two periods later: April and May boundaries are replayed.
      travel_to(Time.zone.local(2026, 5, 10, 10)) { simulate_stripe_webhook(status: "succeeded") }

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.invoices.count).to eq(3)

      replayed_invoices = subscription.invoices.where.not(id: gated_invoice.id)
      replayed_invoices.each do |invoice|
        expect(invoice).to be_finalized
        expect(invoice.invoice_subscriptions.sole.invoicing_reason).to eq("subscription_periodic")
        expect(invoice.fees.subscription.sole.amount_cents).to eq(1000)
        expect(invoice.fees.fixed_charge.sole.units).to eq(10)
        expect(invoice.total_amount_cents).to eq(11_000)
      end

      billed_periods = replayed_invoices.map { |invoice| invoice.invoice_subscriptions.sole }
      expect(billed_periods.map { |period| period.from_datetime.to_date })
        .to contain_exactly(Date.new(2026, 4, 1), Date.new(2026, 5, 1))
      expect(billed_periods.map { |period| period.to_datetime.to_date })
        .to contain_exactly(Date.new(2026, 4, 30), Date.new(2026, 5, 31))

      # Re-running the catch-up skips the already billed periods.
      travel_to(Time.zone.local(2026, 5, 10, 11)) do
        Subscriptions::ActivationRules::BillMissedPeriodsService.call(subscription:)
        perform_all_enqueued_jobs
      end

      expect(subscription.invoices.count).to eq(3)
    end

    context "when the plan interval is yearly" do
      let(:plan) do
        create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 12_000)
      end

      it "bills the full yearly subscription fee with the yearly charges on the missed boundary invoice" do
        travel_to(Time.zone.local(2026, 11, 10, 10)) do
          charge
          create_subscription(subscription_params)
          perform_all_enqueued_jobs
        end

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.invoices.count).to eq(1)

        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 11, 15, 10))
        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 12, 10, 10))

        # Payment succeeds after the yearly period rolled over on January 1.
        travel_to(Time.zone.local(2027, 1, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

        subscription.reload
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(2)

        billed_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 1, 1))
        expect(billed_period.invoicing_reason).to eq("subscription_periodic")
        expect(billed_period.from_datetime.to_date).to eq(Date.new(2027, 1, 1))
        expect(billed_period.to_datetime.to_date).to eq(Date.new(2027, 12, 31))
        expect(billed_period.charges_from_datetime.to_date).to eq(Date.new(2026, 11, 10))
        expect(billed_period.charges_to_datetime.to_date).to eq(Date.new(2026, 12, 31))

        boundary_invoice = billed_period.invoice
        expect(boundary_invoice).to be_finalized
        expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)

        charge_fee = boundary_invoice.fees.charge.sole
        expect(charge_fee.units).to eq(2)
        expect(charge_fee.amount_cents).to eq(1000)

        expect(boundary_invoice.total_amount_cents).to eq(13_000)
      end

      it "bills the full yearly subscription fee with the yearly fixed charges on the missed boundary invoice" do
        travel_to(Time.zone.local(2026, 11, 10, 10)) do
          fixed_charge
          create_subscription(subscription_params)
          perform_all_enqueued_jobs
        end

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.invoices.count).to eq(1)

        # Payment succeeds after the yearly period rolled over on January 1.
        travel_to(Time.zone.local(2027, 1, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

        subscription.reload
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(2)

        billed_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 1, 1))
        expect(billed_period.invoicing_reason).to eq("subscription_periodic")
        expect(billed_period.from_datetime.to_date).to eq(Date.new(2027, 1, 1))
        expect(billed_period.to_datetime.to_date).to eq(Date.new(2027, 12, 31))

        boundary_invoice = billed_period.invoice
        expect(boundary_invoice).to be_finalized
        expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)

        fixed_charge_fee = boundary_invoice.fees.fixed_charge.sole
        expect(fixed_charge_fee.units).to eq(10)
        expect(fixed_charge_fee.amount_cents).to eq(10_000)
        expect(fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2027, 1, 1))
        expect(fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2027, 12, 31))

        expect(boundary_invoice.total_amount_cents).to eq(22_000)
      end

      context "when charges are billed monthly" do
        let(:plan) do
          create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 12_000, bill_charges_monthly: true)
        end

        it "bills the full yearly subscription fee with the last monthly charges on the boundary invoice" do
          travel_to(Time.zone.local(2026, 11, 10, 10)) do
            charge
            create_subscription(subscription_params)
            perform_all_enqueued_jobs
          end

          subscription = customer.subscriptions.sole
          expect(subscription).to be_incomplete
          expect(subscription.invoices.count).to eq(1)

          ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 11, 15, 10))
          ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 12, 10, 10))

          # Payment succeeds after the yearly period rolled over: both the December
          # split tick and the January 1 boundary tick are replayed.
          travel_to(Time.zone.local(2027, 1, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

          subscription.reload
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(3)

          intra_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 12, 1))
          expect(intra_period.invoicing_reason).to eq("subscription_periodic")
          expect(intra_period.charges_from_datetime.to_date).to eq(Date.new(2026, 11, 10))
          expect(intra_period.charges_to_datetime.to_date).to eq(Date.new(2026, 11, 30))

          intra_invoice = intra_period.invoice
          expect(intra_invoice).to be_finalized
          expect(intra_invoice.fees.subscription).to be_empty
          intra_charge_fee = intra_invoice.fees.charge.sole
          expect(intra_charge_fee.units).to eq(1)
          expect(intra_charge_fee.amount_cents).to eq(500)
          expect(intra_invoice.total_amount_cents).to eq(500)

          boundary_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 1, 1))
          expect(boundary_period.invoicing_reason).to eq("subscription_periodic")
          expect(boundary_period.from_datetime.to_date).to eq(Date.new(2027, 1, 1))
          expect(boundary_period.to_datetime.to_date).to eq(Date.new(2027, 12, 31))
          expect(boundary_period.charges_from_datetime.to_date).to eq(Date.new(2026, 12, 1))
          expect(boundary_period.charges_to_datetime.to_date).to eq(Date.new(2026, 12, 31))

          boundary_invoice = boundary_period.invoice
          expect(boundary_invoice).to be_finalized
          expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)
          boundary_charge_fee = boundary_invoice.fees.charge.sole
          expect(boundary_charge_fee.units).to eq(1)
          expect(boundary_charge_fee.amount_cents).to eq(500)
          expect(boundary_invoice.total_amount_cents).to eq(12_500)
        end

        context "when fixed charges are also billed monthly" do
          let(:plan) do
            create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 12_000, bill_charges_monthly: true, bill_fixed_charges_monthly: true)
          end

          it "bills the full yearly subscription fee with both monthly windows on the boundary invoice" do
            travel_to(Time.zone.local(2026, 11, 10, 10)) do
              charge
              fixed_charge
              create_subscription(subscription_params)
              perform_all_enqueued_jobs
            end

            subscription = customer.subscriptions.sole
            expect(subscription).to be_incomplete
            expect(subscription.invoices.count).to eq(1)

            ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 11, 15, 10))
            ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 12, 10, 10))

            # Payment succeeds after the yearly period rolled over: both the December
            # split tick and the January 1 boundary tick are replayed.
            travel_to(Time.zone.local(2027, 1, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

            subscription.reload
            expect(subscription).to be_active
            expect(subscription.invoices.count).to eq(3)

            intra_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 12, 1))
            intra_invoice = intra_period.invoice
            expect(intra_invoice).to be_finalized
            expect(intra_invoice.fees.subscription).to be_empty

            intra_charge_fee = intra_invoice.fees.charge.sole
            expect(intra_charge_fee.units).to eq(1)
            expect(intra_charge_fee.amount_cents).to eq(500)

            intra_fixed_charge_fee = intra_invoice.fees.fixed_charge.sole
            expect(intra_fixed_charge_fee.units).to eq(10)
            expect(intra_fixed_charge_fee.amount_cents).to eq(10_000)
            expect(intra_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2026, 12, 1))
            expect(intra_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2026, 12, 31))

            expect(intra_invoice.total_amount_cents).to eq(10_500)

            boundary_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 1, 1))
            boundary_invoice = boundary_period.invoice
            expect(boundary_invoice).to be_finalized
            expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)

            boundary_charge_fee = boundary_invoice.fees.charge.sole
            expect(boundary_charge_fee.units).to eq(1)
            expect(boundary_charge_fee.amount_cents).to eq(500)

            boundary_fixed_charge_fee = boundary_invoice.fees.fixed_charge.sole
            expect(boundary_fixed_charge_fee.units).to eq(10)
            expect(boundary_fixed_charge_fee.amount_cents).to eq(10_000)
            expect(boundary_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2027, 1, 1))
            expect(boundary_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2027, 1, 31))

            expect(boundary_invoice.total_amount_cents).to eq(22_500)
          end
        end
      end

      context "when fixed charges are billed monthly" do
        let(:plan) do
          create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 12_000, bill_fixed_charges_monthly: true)
        end

        it "bills the full yearly subscription fee with the next monthly fixed charges on the boundary invoice" do
          travel_to(Time.zone.local(2026, 11, 10, 10)) do
            fixed_charge
            create_subscription(subscription_params)
            perform_all_enqueued_jobs
          end

          subscription = customer.subscriptions.sole
          expect(subscription).to be_incomplete
          expect(subscription.invoices.count).to eq(1)

          # Payment succeeds after the yearly period rolled over: both the December
          # split tick and the January 1 boundary tick are replayed.
          travel_to(Time.zone.local(2027, 1, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

          subscription.reload
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(3)

          intra_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 12, 1))
          expect(intra_period.invoicing_reason).to eq("subscription_periodic")

          intra_invoice = intra_period.invoice
          expect(intra_invoice).to be_finalized
          expect(intra_invoice.fees.subscription).to be_empty
          intra_fixed_charge_fee = intra_invoice.fees.fixed_charge.sole
          expect(intra_fixed_charge_fee.units).to eq(10)
          expect(intra_fixed_charge_fee.amount_cents).to eq(10_000)
          expect(intra_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2026, 12, 1))
          expect(intra_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2026, 12, 31))
          expect(intra_invoice.total_amount_cents).to eq(10_000)

          boundary_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 1, 1))
          expect(boundary_period.invoicing_reason).to eq("subscription_periodic")
          expect(boundary_period.from_datetime.to_date).to eq(Date.new(2027, 1, 1))
          expect(boundary_period.to_datetime.to_date).to eq(Date.new(2027, 12, 31))

          boundary_invoice = boundary_period.invoice
          expect(boundary_invoice).to be_finalized
          expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)
          boundary_fixed_charge_fee = boundary_invoice.fees.fixed_charge.sole
          expect(boundary_fixed_charge_fee.units).to eq(10)
          expect(boundary_fixed_charge_fee.amount_cents).to eq(10_000)
          expect(boundary_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2027, 1, 1))
          expect(boundary_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2027, 1, 31))
          expect(boundary_invoice.total_amount_cents).to eq(22_000)
        end
      end
    end

    context "when the plan interval is semiannual" do
      let(:plan) do
        create(:plan, organization:, interval: :semiannual, pay_in_advance: true, amount_cents: 6_000)
      end

      it "bills the full semiannual subscription fee with the semiannual charges on the missed boundary invoice" do
        travel_to(Time.zone.local(2026, 5, 10, 10)) do
          charge
          create_subscription(subscription_params)
          perform_all_enqueued_jobs
        end

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.invoices.count).to eq(1)

        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 5, 15, 10))
        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 6, 10, 10))

        # Payment succeeds after the semiannual period rolled over on July 1.
        travel_to(Time.zone.local(2026, 7, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

        subscription.reload
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(2)

        billed_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 7, 1))
        expect(billed_period.invoicing_reason).to eq("subscription_periodic")
        expect(billed_period.from_datetime.to_date).to eq(Date.new(2026, 7, 1))
        expect(billed_period.to_datetime.to_date).to eq(Date.new(2026, 12, 31))
        expect(billed_period.charges_from_datetime.to_date).to eq(Date.new(2026, 5, 10))
        expect(billed_period.charges_to_datetime.to_date).to eq(Date.new(2026, 6, 30))

        boundary_invoice = billed_period.invoice
        expect(boundary_invoice).to be_finalized
        expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(6_000)

        charge_fee = boundary_invoice.fees.charge.sole
        expect(charge_fee.units).to eq(2)
        expect(charge_fee.amount_cents).to eq(1000)

        expect(boundary_invoice.total_amount_cents).to eq(7_000)
      end

      it "bills the full semiannual subscription fee with the semiannual fixed charges on the missed boundary invoice" do
        travel_to(Time.zone.local(2026, 5, 10, 10)) do
          fixed_charge
          create_subscription(subscription_params)
          perform_all_enqueued_jobs
        end

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.invoices.count).to eq(1)

        # Payment succeeds after the semiannual period rolled over on July 1.
        travel_to(Time.zone.local(2026, 7, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

        subscription.reload
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(2)

        billed_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 7, 1))
        expect(billed_period.invoicing_reason).to eq("subscription_periodic")
        expect(billed_period.from_datetime.to_date).to eq(Date.new(2026, 7, 1))
        expect(billed_period.to_datetime.to_date).to eq(Date.new(2026, 12, 31))

        boundary_invoice = billed_period.invoice
        expect(boundary_invoice).to be_finalized
        expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(6_000)

        fixed_charge_fee = boundary_invoice.fees.fixed_charge.sole
        expect(fixed_charge_fee.units).to eq(10)
        expect(fixed_charge_fee.amount_cents).to eq(10_000)
        expect(fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2026, 7, 1))
        expect(fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2026, 12, 31))

        expect(boundary_invoice.total_amount_cents).to eq(16_000)
      end

      context "when charges are billed monthly" do
        let(:plan) do
          create(:plan, organization:, interval: :semiannual, pay_in_advance: true, amount_cents: 6_000, bill_charges_monthly: true)
        end

        it "bills the full semiannual subscription fee with the last monthly charges on the boundary invoice" do
          travel_to(Time.zone.local(2026, 5, 10, 10)) do
            charge
            create_subscription(subscription_params)
            perform_all_enqueued_jobs
          end

          subscription = customer.subscriptions.sole
          expect(subscription).to be_incomplete
          expect(subscription.invoices.count).to eq(1)

          ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 5, 15, 10))
          ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 6, 10, 10))

          # Payment succeeds after the semiannual period rolled over: both the June
          # split tick and the July 1 boundary tick are replayed.
          travel_to(Time.zone.local(2026, 7, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

          subscription.reload
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(3)

          intra_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 6, 1))
          expect(intra_period.invoicing_reason).to eq("subscription_periodic")
          expect(intra_period.charges_from_datetime.to_date).to eq(Date.new(2026, 5, 10))
          expect(intra_period.charges_to_datetime.to_date).to eq(Date.new(2026, 5, 31))

          intra_invoice = intra_period.invoice
          expect(intra_invoice).to be_finalized
          expect(intra_invoice.fees.subscription).to be_empty
          intra_charge_fee = intra_invoice.fees.charge.sole
          expect(intra_charge_fee.units).to eq(1)
          expect(intra_charge_fee.amount_cents).to eq(500)
          expect(intra_invoice.total_amount_cents).to eq(500)

          boundary_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 7, 1))
          expect(boundary_period.invoicing_reason).to eq("subscription_periodic")
          expect(boundary_period.from_datetime.to_date).to eq(Date.new(2026, 7, 1))
          expect(boundary_period.to_datetime.to_date).to eq(Date.new(2026, 12, 31))
          expect(boundary_period.charges_from_datetime.to_date).to eq(Date.new(2026, 6, 1))
          expect(boundary_period.charges_to_datetime.to_date).to eq(Date.new(2026, 6, 30))

          boundary_invoice = boundary_period.invoice
          expect(boundary_invoice).to be_finalized
          expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(6_000)
          boundary_charge_fee = boundary_invoice.fees.charge.sole
          expect(boundary_charge_fee.units).to eq(1)
          expect(boundary_charge_fee.amount_cents).to eq(500)
          expect(boundary_invoice.total_amount_cents).to eq(6_500)
        end
      end

      context "when fixed charges are billed monthly" do
        let(:plan) do
          create(:plan, organization:, interval: :semiannual, pay_in_advance: true, amount_cents: 6_000, bill_fixed_charges_monthly: true)
        end

        it "bills the full semiannual subscription fee with the next monthly fixed charges on the boundary invoice" do
          travel_to(Time.zone.local(2026, 5, 10, 10)) do
            fixed_charge
            create_subscription(subscription_params)
            perform_all_enqueued_jobs
          end

          subscription = customer.subscriptions.sole
          expect(subscription).to be_incomplete
          expect(subscription.invoices.count).to eq(1)

          # Payment succeeds after the semiannual period rolled over: both the June
          # split tick and the July 1 boundary tick are replayed.
          travel_to(Time.zone.local(2026, 7, 5, 10)) { simulate_stripe_webhook(status: "succeeded") }

          subscription.reload
          expect(subscription).to be_active
          expect(subscription.invoices.count).to eq(3)

          intra_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 6, 1))
          expect(intra_period.invoicing_reason).to eq("subscription_periodic")

          intra_invoice = intra_period.invoice
          expect(intra_invoice).to be_finalized
          expect(intra_invoice.fees.subscription).to be_empty
          intra_fixed_charge_fee = intra_invoice.fees.fixed_charge.sole
          expect(intra_fixed_charge_fee.units).to eq(10)
          expect(intra_fixed_charge_fee.amount_cents).to eq(10_000)
          expect(intra_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2026, 6, 1))
          expect(intra_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2026, 6, 30))
          expect(intra_invoice.total_amount_cents).to eq(10_000)

          boundary_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2026, 7, 1))
          expect(boundary_period.invoicing_reason).to eq("subscription_periodic")
          expect(boundary_period.from_datetime.to_date).to eq(Date.new(2026, 7, 1))
          expect(boundary_period.to_datetime.to_date).to eq(Date.new(2026, 12, 31))

          boundary_invoice = boundary_period.invoice
          expect(boundary_invoice).to be_finalized
          expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(6_000)
          boundary_fixed_charge_fee = boundary_invoice.fees.fixed_charge.sole
          expect(boundary_fixed_charge_fee.units).to eq(10)
          expect(boundary_fixed_charge_fee.amount_cents).to eq(10_000)
          expect(boundary_fixed_charge_fee.properties["fixed_charges_from_datetime"].to_date).to eq(Date.new(2026, 7, 1))
          expect(boundary_fixed_charge_fee.properties["fixed_charges_to_datetime"].to_date).to eq(Date.new(2026, 7, 31))
          expect(boundary_invoice.total_amount_cents).to eq(16_000)
        end
      end
    end

    context "when a yearly plan is billed on its anniversary" do
      let(:plan) do
        create(:plan, organization:, interval: :yearly, pay_in_advance: true, amount_cents: 12_000)
      end

      it "bills the full yearly subscription fee with the yearly charges on the anniversary boundary invoice" do
        travel_to(Time.zone.local(2026, 11, 10, 10)) do
          charge
          create_subscription(subscription_params.merge(billing_time: "anniversary"))
          perform_all_enqueued_jobs
        end

        subscription = customer.subscriptions.sole
        expect(subscription).to be_incomplete
        expect(subscription.invoices.count).to eq(1)

        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 11, 15, 10))
        ingest_usage_event(subscription, timestamp: Time.zone.local(2026, 12, 10, 10))

        # Payment succeeds after the anniversary boundary on November 10, 2027.
        travel_to(Time.zone.local(2027, 11, 15, 10)) { simulate_stripe_webhook(status: "succeeded") }

        subscription.reload
        expect(subscription).to be_active
        expect(subscription.invoices.count).to eq(2)

        billed_period = subscription.invoice_subscriptions.find_by(timestamp: Time.zone.local(2027, 11, 10))
        expect(billed_period.invoicing_reason).to eq("subscription_periodic")
        expect(billed_period.from_datetime.to_date).to eq(Date.new(2027, 11, 10))
        expect(billed_period.to_datetime.to_date).to eq(Date.new(2028, 11, 9))
        expect(billed_period.charges_from_datetime.to_date).to eq(Date.new(2026, 11, 10))
        expect(billed_period.charges_to_datetime.to_date).to eq(Date.new(2027, 11, 9))

        boundary_invoice = billed_period.invoice
        expect(boundary_invoice).to be_finalized
        expect(boundary_invoice.fees.subscription.sole.amount_cents).to eq(12_000)

        charge_fee = boundary_invoice.fees.charge.sole
        expect(charge_fee.units).to eq(2)
        expect(charge_fee.amount_cents).to eq(1000)

        expect(boundary_invoice.total_amount_cents).to eq(13_000)
      end
    end
  end

  describe "timeout: subscription cancels on activation rule expiry" do
    before do
      # Best-effort PSP cancel calls Stripe; mock the SDK to return a canceled intent.
      allow(::Stripe::PaymentIntent).to receive(:cancel).and_return(
        ::Stripe::PaymentIntent.construct_from(
          id: payment_intent_id,
          object: "payment_intent",
          status: "canceled",
          amount: 1000,
          currency: "eur"
        )
      )
    end

    it "expires the gated subscription with cancellation_reason: timeout" do
      # Stage 1: Create gated subscription
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.activation_rules.sole).to be_pending

      invoice = subscription.invoices.sole
      expect(invoice).to be_open

      # Stage 2: Simulate timeout — push the rule's expires_at into the past
      subscription.activation_rules.sole.update!(expires_at: 1.hour.ago)

      # Stage 3: Clock job runs — picks up the expired rule, enqueues ExpireIncompleteJob
      Clock::ExpireIncompleteSubscriptionsJob.perform_now
      perform_all_enqueued_jobs

      subscription.reload
      expect(subscription).to be_canceled
      expect(subscription.cancellation_reason).to eq("timeout")
      expect(subscription.activation_rules.sole).to be_expired

      expect(invoice.reload).to be_closed
    end

    it "does not act on subscriptions whose rule has not yet expired" do
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete

      # Rule's expires_at is still in the future (48 hours from creation)
      Clock::ExpireIncompleteSubscriptionsJob.perform_now
      perform_all_enqueued_jobs

      expect(subscription.reload).to be_incomplete
      expect(subscription.activation_rules.sole).to be_pending
    end

    context "with consumed coupon, credit note, and wallet credits" do
      let(:coupon) do
        create(:coupon, organization:, coupon_type: :fixed_amount,
          amount_cents: 10, amount_currency: "EUR", frequency: :once)
      end
      let(:applied_coupon) do
        create(:applied_coupon, customer:, coupon:, organization:,
          amount_cents: 10, amount_currency: "EUR", frequency: :once, status: :active)
      end
      let(:source_invoice) do
        create(:invoice, customer:, organization:, status: :finalized, currency: "EUR")
      end
      let(:credit_note) do
        create(:credit_note, customer:, organization:, invoice: source_invoice,
          credit_status: :available,
          total_amount_cents: 10, total_amount_currency: "EUR",
          credit_amount_cents: 10, credit_amount_currency: "EUR",
          balance_amount_cents: 10, balance_amount_currency: "EUR")
      end
      let(:wallet) do
        create(:wallet, :with_inbound_transaction, customer:, organization:, currency: "EUR",
          balance_cents: 10, credits_balance: 0.1, rate_amount: 1)
      end

      before do
        applied_coupon
        credit_note
        wallet
      end

      it "restores the coupon, credit note balance, and wallet credits when the rule expires" do
        create_subscription(subscription_params)
        perform_all_enqueued_jobs

        invoice = customer.subscriptions.sole.invoices.sole
        expect(invoice).to be_open

        # Resources consumed by the gated invoice
        expect(applied_coupon.reload).to be_terminated
        expect(credit_note.reload.balance_amount_cents).to eq(0)
        expect(credit_note).to be_consumed
        expect(wallet.reload.balance_cents).to eq(0)

        # Travel past the 48h timeout so the rule expires, then run the clock
        travel_to(49.hours.from_now) do
          Clock::ExpireIncompleteSubscriptionsJob.perform_now
          perform_all_enqueued_jobs
        end

        expect(invoice.reload).to be_closed

        # Resources restored after the gated invoice was closed
        expect(applied_coupon.reload).to be_active
        expect(applied_coupon.remaining_amount).to eq(10)
        expect(credit_note.reload.balance_amount_cents).to eq(10)
        expect(credit_note).to be_available
        expect(wallet.reload.balance_cents).to eq(10)
        expect(wallet.wallet_transactions.inbound.where(voided_invoice_id: invoice.id)).to exist
      end

      context "when the credit note is voided" do
        let(:credit_note) do
          create(:credit_note, customer:, organization:, invoice: source_invoice,
            credit_status: :voided,
            total_amount_cents: 10, total_amount_currency: "EUR",
            credit_amount_cents: 10, credit_amount_currency: "EUR",
            balance_amount_cents: 10, balance_amount_currency: "EUR")
        end

        it "leaves the voided credit note untouched when the rule expires" do
          create_subscription(subscription_params)
          perform_all_enqueued_jobs

          invoice = customer.subscriptions.sole.invoices.sole
          expect(invoice.credits.credit_note_kind).to be_empty

          travel_to(49.hours.from_now) do
            Clock::ExpireIncompleteSubscriptionsJob.perform_now
            perform_all_enqueued_jobs
          end

          expect(invoice.reload).to be_closed
          expect(credit_note.reload).to be_voided
          expect(credit_note.balance_amount_cents).to eq(10)
        end
      end

      context "when the wallet is terminated" do
        let(:wallet) do
          create(:wallet, :terminated, customer:, organization:, currency: "EUR",
            balance_cents: 10, credits_balance: 0.1, rate_amount: 1)
        end

        it "leaves the terminated wallet untouched when the rule expires" do
          create_subscription(subscription_params)
          perform_all_enqueued_jobs

          invoice = customer.subscriptions.sole.invoices.sole
          expect(invoice.wallet_transactions.outbound).to be_empty

          travel_to(49.hours.from_now) do
            Clock::ExpireIncompleteSubscriptionsJob.perform_now
            perform_all_enqueued_jobs
          end

          expect(invoice.reload).to be_closed
          expect(wallet.reload).to be_terminated
          expect(wallet.balance_cents).to eq(10)
          expect(wallet.wallet_transactions.inbound.where(voided_invoice_id: invoice.id)).not_to exist
        end
      end
    end
  end

  describe "gated subscription with pending VIES check" do
    let(:vat_number) { "IT12345678901" }
    let(:organization) do
      create(:organization, country: "FR", webhook_url: nil, eu_tax_management: true,
        billing_entities: [create(:billing_entity, country: "FR", eu_tax_management: true)])
    end
    let(:billing_entity) { organization.billing_entities.first }
    let(:customer) do
      create(:customer, organization:, billing_entity:, country: "IT", currency: "EUR",
        tax_identification_number: vat_number)
    end

    before do
      create(:pending_vies_check, customer:, tax_identification_number: vat_number)
    end

    it "stays gated until VIES resolves, then activates on payment success" do
      # Stage 1: Create subscription — invoice goes :open with tax_status :pending (VIES blocks taxes)
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.activation_rules.sole).to be_pending

      invoice = subscription.invoices.sole
      expect(invoice).to be_open
      expect(invoice.tax_status).to eq("pending")

      # Stage 2: VIES resolves — FinalizePendingViesInvoiceService applies taxes and triggers payment
      mock_vies_check!(vat_number)
      Customers::ViesCheckJob.perform_now(customer)
      perform_all_enqueued_jobs

      invoice.reload
      expect(invoice.tax_status).to eq("succeeded")
      expect(invoice).to be_open

      # Stage 3: Stripe webhook — payment succeeded, subscription activates
      simulate_stripe_webhook(status: "succeeded")

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.activation_rules.sole).to be_satisfied
      expect(invoice.reload).to be_finalized
    end
  end

  describe "gated subscription with provider tax failure" do
    let(:tax_integration) { create(:anrok_integration, organization:) }
    let(:tax_integration_customer) { create(:anrok_customer, integration: tax_integration, customer:) }
    let(:anrok_client) { instance_double(LagoHttpClient::Client) }
    let(:anrok_finalized_endpoint) { "https://api.nango.dev/v1/anrok/finalized_invoices" }
    let(:anrok_draft_endpoint) { "https://api.nango.dev/v1/anrok/draft_invoices" }
    let(:failure_body) { File.read(Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/failure_response.json")) }
    let(:success_body_template) { JSON.parse(File.read(Rails.root.join("spec/fixtures/integration_aggregator/taxes/invoices/success_response.json"))) }

    before do
      tax_integration_customer
      allow(LagoHttpClient::Client).to receive(:new).and_call_original
      allow(LagoHttpClient::Client).to receive(:new).with(anrok_finalized_endpoint, anything).and_return(anrok_client)
      allow(LagoHttpClient::Client).to receive(:new).with(anrok_draft_endpoint, anything).and_return(anrok_client)
      stub_anrok_response(failure_body)
    end

    def stub_anrok_response(body)
      response = instance_double(Net::HTTPOK)
      allow(response).to receive(:body).and_return(body)
      allow(anrok_client).to receive(:post_with_response).and_return(response)
    end

    def success_body_for(invoice)
      body = success_body_template.deep_dup
      body["succeededInvoices"].first["fees"].first["item_id"] = invoice.fees.first.id
      body.to_json
    end

    it "fails on tax error, retries successfully, then activates on payment success" do
      # Stage 1: Create subscription — Anrok fails → invoice :failed
      create_subscription(subscription_params)
      perform_all_enqueued_jobs

      subscription = customer.subscriptions.sole
      expect(subscription).to be_incomplete
      expect(subscription.activation_rules.sole).to be_pending

      invoice = subscription.invoices.sole
      expect(invoice).to be_failed
      expect(invoice.tax_status).to eq("failed")

      # Stage 2: Re-stub Anrok to succeed, then retry. Invoice goes :open with taxes
      # applied; PullTaxesAndApplyService triggers payment for the gated case.
      stub_anrok_response(success_body_for(invoice))
      Invoices::RetryService.call!(invoice:)
      perform_all_enqueued_jobs

      invoice.reload
      expect(invoice).to be_open
      expect(invoice.tax_status).to eq("succeeded")

      # Stage 3: Stripe webhook — payment succeeded, subscription activates
      simulate_stripe_webhook(status: "succeeded")

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.activation_rules.sole).to be_satisfied
      expect(invoice.reload).to be_finalized
    end
  end

  describe "plan upgrade with payment successful" do
    let(:previous_plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: false, amount_cents: 500)
    end
    let(:upgrade_external_id) { "upgrade-sub-#{SecureRandom.hex(4)}" }
    let(:add_on) { create(:add_on, organization:) }
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000) do |plan|
        create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
      end
    end
    let(:fixed_charge) { plan.fixed_charges.sole }

    # These scenarios can span several days, so the upgrading invoice for the
    # previous subscription is non-zero and triggers a second payment intent —
    # return a unique id per call, as Stripe does.
    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}", status: "processing", amount: 1000, currency: "eur"
          )
        end
    end

    it "gates the upgrade, then terminates previous and activates new on payment success" do
      # Stage 1: Create initial active subscription on cheaper pay-in-arrears plan (no rules)
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: upgrade_external_id,
        plan_code: previous_plan.code,
        billing_time: "calendar"
      })
      perform_all_enqueued_jobs

      previous_subscription = customer.subscriptions.sole
      expect(previous_subscription).to be_active
      expect(previous_subscription.plan).to eq(previous_plan)

      # Stage 2: Upgrade to pricier pay-in-advance plan with payment activation rule
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: upgrade_external_id,
        plan_code: plan.code,
        billing_time: "calendar",
        activation_rules: [{type: "payment", timeout_hours: 48}]
      })
      perform_all_enqueued_jobs

      new_subscription = customer.subscriptions.where.not(id: previous_subscription.id).sole
      expect(previous_subscription.reload).to be_active
      expect(new_subscription).to be_incomplete
      expect(new_subscription.previous_subscription).to eq(previous_subscription)
      expect(new_subscription.activation_rules.sole).to be_pending

      invoice = new_subscription.invoices.sole
      expect(invoice).to be_open
      expect(invoice.fees.subscription.count).to eq(1)

      # Stage 3: Stripe webhook — payment succeeded → upgrade completes
      expect { simulate_stripe_webhook(status: "succeeded") }
        .to have_performed_job(BillSubscriptionJob)
        .with([previous_subscription], anything, invoicing_reason: :upgrading)

      previous_subscription.reload
      new_subscription.reload
      expect(previous_subscription).to be_terminated
      expect(new_subscription).to be_active
      expect(new_subscription.activated_at).to be_present
      expect(new_subscription.activation_rules.sole).to be_satisfied
      expect(invoice.reload).to be_finalized
    end

    it "bills a unit increase applied immediately as a delta invoice on activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        # Stage 1: initial active subscription on the cheaper pay-in-arrears plan (no rules)
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: upgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs

        # Stage 2: gated upgrade to the pricier pay-in-advance plan with a payment activation rule
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: upgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      previous_subscription = customer.subscriptions.where(plan: previous_plan).sole
      new_subscription = customer.subscriptions.where(plan:).sole
      expect(new_subscription).to be_incomplete
      expect(new_subscription.invoices.count).to eq(1)

      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10))

      travel_to(Time.zone.local(2026, 3, 20, 10)) { simulate_stripe_webhook(status: "succeeded") }

      new_subscription.reload
      expect(new_subscription).to be_active
      expect(previous_subscription.reload).to be_terminated
      expect(new_subscription.invoices.count).to eq(2)

      delta_invoice = new_subscription.invoices.order(:created_at).last
      expect(delta_invoice.fees.fixed_charge.sole.units).to eq(5)
    end

    it "defers a unit change scheduled for the next billing period until the following billing run on cross-period activation" do
      travel_to(Time.zone.local(2026, 3, 1, 10)) do
        # Stage 1: initial active subscription on the cheaper pay-in-arrears plan (no rules)
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: upgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs

        # Stage 2: gated upgrade to the pricier pay-in-advance plan with a payment activation rule
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: upgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      previous_subscription = customer.subscriptions.where(plan: previous_plan).sole
      new_subscription = customer.subscriptions.where(plan:).sole
      expect(new_subscription).to be_incomplete

      # Scheduled change: the event is stamped at the next period start (April 1).
      update_fixed_charge_units(fixed_charge, 15, timestamp: Time.zone.local(2026, 3, 10, 10), apply_units_immediately: false)

      travel_to(Time.zone.local(2026, 4, 3, 10)) { simulate_stripe_webhook(status: "succeeded") }

      new_subscription.reload
      expect(new_subscription).to be_active
      expect(previous_subscription.reload).to be_terminated

      # No delta invoice and no missed-period invoice for the upgraded subscription:
      # the previous subscription covered the service until activation.
      expect(new_subscription.invoices.count).to eq(1)

      # The next regular billing run reflects the scheduled units.
      travel_to(Time.zone.local(2026, 5, 1, 1)) { perform_billing }

      expect(new_subscription.invoices.count).to eq(2)
      periodic_invoice = new_subscription.invoices.order(:created_at).last
      expect(periodic_invoice.fees.fixed_charge.sole.units).to eq(15)
    end
  end

  describe "plan upgrade with payment failure" do
    let(:previous_plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: false, amount_cents: 500)
    end
    let(:upgrade_external_id) { "upgrade-sub-#{SecureRandom.hex(4)}" }

    it "cancels the new subscription and leaves the previous untouched" do
      # Stage 1: initial active subscription on cheaper plan
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: upgrade_external_id,
        plan_code: previous_plan.code,
        billing_time: "calendar"
      })
      perform_all_enqueued_jobs

      previous_subscription = customer.subscriptions.sole
      expect(previous_subscription).to be_active

      # Stage 2: gated upgrade
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: upgrade_external_id,
        plan_code: plan.code,
        billing_time: "calendar",
        activation_rules: [{type: "payment", timeout_hours: 48}]
      })
      perform_all_enqueued_jobs

      new_subscription = customer.subscriptions.where.not(id: previous_subscription.id).sole
      expect(new_subscription).to be_incomplete

      invoice = new_subscription.invoices.sole
      expect(invoice).to be_open

      # Stage 3: Stripe webhook — payment failed
      simulate_stripe_webhook(status: "failed")

      previous_subscription.reload
      new_subscription.reload
      expect(new_subscription).to be_canceled
      expect(new_subscription.cancellation_reason).to eq("payment_failed")
      expect(new_subscription.activation_rules.sole).to be_failed
      expect(previous_subscription).to be_active
      expect(invoice.reload).to be_closed
    end
  end

  describe "plan downgrade with payment successful", transaction: false do
    let(:previous_plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: false, amount_cents: 2000)
    end
    let(:downgrade_external_id) { "downgrade-sub-#{SecureRandom.hex(4)}" }
    let(:add_on) { create(:add_on, organization:) }
    let(:plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000) do |plan|
        create(:fixed_charge, :pay_in_advance, plan:, add_on:, units: 10, properties: {amount: "10"})
      end
    end
    let(:fixed_charge) { plan.fixed_charges.sole }

    # This scenario spans a real billing period, so terminating the previous subscription on
    # activation produces a non-zero invoice and thus a second payment intent.
    # The shared stub returns a fixed payment_intent_id, which would collide
    # with the gated invoice's payment on the second call — return a unique id per call, as Stripe
    # does.
    before do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent) do
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}",
            status: "processing",
            amount: 1000,
            currency: "eur"
          )
        end
    end

    it "gates the downgrade at the billing boundary, then terminates previous and activates new on payment success" do
      # Stage 1: active subscription on the pricier plan (no rules)
      travel_to(DateTime.new(2024, 1, 10)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs
      end

      previous_subscription = customer.subscriptions.sole
      expect(previous_subscription).to be_active
      expect(previous_subscription.plan).to eq(previous_plan)

      # Stage 2: downgrade to the cheaper pay-in-advance plan with a payment activation rule.
      # The downgrade is created pending and only activated at the next billing day.
      travel_to(DateTime.new(2024, 1, 20)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      new_subscription = customer.subscriptions.where.not(id: previous_subscription.id).sole
      expect(new_subscription).to be_pending
      expect(new_subscription.previous_subscription).to eq(previous_subscription)
      expect(previous_subscription.reload).to be_active

      # Stage 3: next billing day — the rotation gates the pending downgrade rather than activating it.
      travel_to(DateTime.new(2024, 2, 1)) do
        perform_billing
      end

      new_subscription.reload
      expect(new_subscription).to be_incomplete
      expect(new_subscription.activation_rules.sole).to be_pending
      expect(previous_subscription.reload).to be_active

      invoice = new_subscription.invoices.sole
      expect(invoice).to be_open
      expect(invoice.fees.subscription.count).to eq(1)

      # Stage 4: Stripe webhook — payment succeeded → previous terminates, downgrade activates
      travel_to(DateTime.new(2024, 2, 1)) do
        expect { simulate_stripe_webhook(status: "succeeded") }
          .to have_performed_job(BillSubscriptionJob)
          .with([previous_subscription], anything, invoicing_reason: :upgrading)
      end

      previous_subscription.reload
      new_subscription.reload
      expect(previous_subscription).to be_terminated
      expect(new_subscription).to be_active
      expect(new_subscription.activated_at).to be_present
      expect(new_subscription.activation_rules.sole).to be_satisfied
      expect(invoice.reload).to be_finalized
    end

    it "bills a unit increase applied immediately as a delta invoice on activation" do
      # Stage 1: active subscription on the pricier plan (no rules)
      travel_to(DateTime.new(2026, 1, 10)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs
      end

      # Stage 2: downgrade to the cheaper pay-in-advance plan with a payment activation rule.
      # The downgrade is created pending and only activated at the next billing day.
      travel_to(DateTime.new(2026, 1, 20)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      # Stage 3: next billing day — the rotation gates the pending downgrade.
      travel_to(DateTime.new(2026, 2, 1)) { perform_billing }

      previous_subscription = customer.subscriptions.where(plan: previous_plan).sole
      new_subscription = customer.subscriptions.where(plan:).sole
      expect(new_subscription).to be_incomplete

      gated_invoice = new_subscription.invoices.sole
      expect(gated_invoice.fees.fixed_charge.sole.units).to eq(10)

      update_fixed_charge_units(fixed_charge, 15, timestamp: DateTime.new(2026, 2, 10))

      travel_to(DateTime.new(2026, 2, 20)) do
        simulate_stripe_webhook(status: "succeeded", invoice: gated_invoice)
      end

      new_subscription.reload
      expect(new_subscription).to be_active
      expect(previous_subscription.reload).to be_terminated
      expect(new_subscription.invoices.count).to eq(2)

      delta_invoice = new_subscription.invoices.order(:created_at).last
      expect(delta_invoice.fees.fixed_charge.sole.units).to eq(5)
    end

    it "defers a unit change scheduled for the next billing period until the following billing run on cross-period activation" do
      # Stage 1: active subscription on the pricier plan (no rules)
      travel_to(DateTime.new(2026, 1, 10)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs
      end

      # Stage 2: downgrade to the cheaper pay-in-advance plan with a payment activation rule.
      # The downgrade is created pending and only activated at the next billing day.
      travel_to(DateTime.new(2026, 1, 20)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      # Stage 3: next billing day — the rotation gates the pending downgrade.
      travel_to(DateTime.new(2026, 2, 1)) { perform_billing }

      previous_subscription = customer.subscriptions.where(plan: previous_plan).sole
      new_subscription = customer.subscriptions.where(plan:).sole
      expect(new_subscription).to be_incomplete

      gated_invoice = new_subscription.invoices.sole

      # Scheduled change: the event is stamped at the next period start (March 1).
      update_fixed_charge_units(fixed_charge, 15, timestamp: DateTime.new(2026, 2, 10), apply_units_immediately: false)

      travel_to(DateTime.new(2026, 3, 5)) do
        simulate_stripe_webhook(status: "succeeded", invoice: gated_invoice)
      end

      new_subscription.reload
      expect(new_subscription).to be_active
      expect(previous_subscription.reload).to be_terminated

      # No delta invoice and no missed-period invoice for the downgraded subscription:
      # the previous subscription covered the service until activation.
      expect(new_subscription.invoices.count).to eq(1)

      # The next regular billing run reflects the scheduled units.
      travel_to(DateTime.new(2026, 4, 1)) { perform_billing }

      expect(new_subscription.invoices.count).to eq(2)
      periodic_invoice = new_subscription.invoices.order(:created_at).last
      expect(periodic_invoice.fees.fixed_charge.sole.units).to eq(15)
    end
  end

  describe "plan downgrade with payment failure", transaction: false do
    let(:previous_plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: false, amount_cents: 2000)
    end
    let(:downgrade_external_id) { "downgrade-sub-#{SecureRandom.hex(4)}" }

    it "cancels the new subscription and leaves the previous untouched" do
      # Stage 1: active subscription on the pricier plan
      travel_to(DateTime.new(2024, 1, 10)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: previous_plan.code,
          billing_time: "calendar"
        })
        perform_all_enqueued_jobs
      end

      previous_subscription = customer.subscriptions.sole
      expect(previous_subscription).to be_active

      # Stage 2: gated downgrade (pending until next billing day)
      travel_to(DateTime.new(2024, 1, 20)) do
        create_subscription({
          external_customer_id: customer.external_id,
          external_id: downgrade_external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          activation_rules: [{type: "payment", timeout_hours: 48}]
        })
        perform_all_enqueued_jobs
      end

      new_subscription = customer.subscriptions.where.not(id: previous_subscription.id).sole
      expect(new_subscription).to be_pending

      # Stage 3: next billing day — rotation gates the downgrade
      travel_to(DateTime.new(2024, 2, 1)) do
        perform_billing
      end

      new_subscription.reload
      expect(new_subscription).to be_incomplete

      invoice = new_subscription.invoices.sole
      expect(invoice).to be_open

      # Stage 4: Stripe webhook — payment failed
      travel_to(DateTime.new(2024, 2, 1)) do
        simulate_stripe_webhook(status: "failed")
      end

      previous_subscription.reload
      new_subscription.reload
      expect(new_subscription).to be_canceled
      expect(new_subscription.cancellation_reason).to eq("payment_failed")
      expect(new_subscription.activation_rules.sole).to be_failed
      expect(previous_subscription).to be_active
      expect(invoice.reload).to be_closed
    end
  end
end
