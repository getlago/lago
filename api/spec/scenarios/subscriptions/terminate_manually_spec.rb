# frozen_string_literal: true

require "rails_helper"

describe "Subscription manual termination" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:, timezone: "UTC") }
  let(:billable_metric) { create(:sum_billable_metric, organization:, field_name: "item_count") }
  let(:plan) { create(:plan, :pay_in_advance, organization:, amount_cents: 100_00) }
  let(:subscription_date) { DateTime.new(2025, 2, 8) }
  let(:termination_date) { DateTime.new(2025, 2, 21) }
  let(:events_date) { DateTime.new(2025, 2, 10) }

  before do
    create(:tax, :applied_to_billing_entity, organization:, rate: 20)
    create(:standard_charge, billable_metric:, plan:, properties: {amount: "1"})
  end

  def credit_note
    @credit_note ||= subscription_invoice.credit_notes.sole
  end

  def subscription
    @subscription ||= customer.subscriptions.find_by(external_id: customer.external_id)
  end

  def subscription_invoice
    @subscription_invoice ||= subscription.invoices.order(:number).first
  end

  def billed_invoice
    @billed_invoice ||= subscription.invoices.order(:number).last
  end

  def create_subscription(params = {})
    travel_to(subscription_date) do
      super(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        }.merge(params)
      )
    end
  end

  def terminate_subscription_without_jobs(subscription, params = {}, raise_on_error: true)
    travel_to(termination_date) do
      terminate_subscription(subscription, params:, perform_jobs: false, raise_on_error:)
    end
    subscription.reload
    # we don't have a subscription invoice for pending or pay-in-arrears subscriptions
    subscription_invoice&.reload
  end

  # 5 events * 10 item_count * 1 euro = 50 euro
  def add_events_to_subscription
    travel_to(events_date) do
      5.times do
        create_event(
          {code: billable_metric.code,
           transaction_id: SecureRandom.uuid,
           external_subscription_id: subscription.external_id,
           properties: {"item_count" => 10}}
        )
      end
    end
  end

  def perform_termination_jobs
    travel_to(termination_date) do
      perform_all_enqueued_jobs
    end
  end

  def expect_charge_fees_to_be_billed
    charge_fee = billed_invoice.fees.charge.sole

    expect(charge_fee).to be_present
    expect(charge_fee.amount_cents).to eq(50_00)
    expect(charge_fee.taxes_amount_cents).to eq(10_00)
  end

  def expect_credit_note_to_be_created(amount_cents)
    expect(subscription.credit_notes.count).to eq(1)
    expect(subscription.on_termination_credit_note).to eq("credit")
    expect(subscription_invoice.credit_notes.sole.credit_amount_cents).to eq(amount_cents)
  end

  def expect_pay_in_advance_to_be_billed
    expect(subscription.status).to eq("active")

    expect(subscription_invoice.credit_notes.count).to eq(0)

    # (21 days out of 28 days = 75% of the month = 75 euro) + 20% tax = 90 euro
    expect(subscription_invoice.taxes_amount_cents).to eq(15_00)
    expect(subscription_invoice.total_amount_cents).to eq(90_00)
  end

  def expect_subscription_to_be_terminated(on_termination_credit_note: "credit", on_termination_invoice: "generate")
    expect(subscription.status).to eq("terminated")
    expect(subscription.on_termination_credit_note).to eq(on_termination_credit_note)
    expect(subscription.on_termination_invoice).to eq(on_termination_invoice)
  end

  def expect_credit_note_to_be_created(refund_amount_cents: 0)
    # (7 unused days = 7 / 28 * 100 = 25 euro) + 20% tax = 30 euro
    total_amount_cents = 30_00
    credit_amount_cents = total_amount_cents - refund_amount_cents
    expect(credit_note.total_amount_cents).to eq(total_amount_cents)
    expect(credit_note.credit_amount_cents).to eq(credit_amount_cents)
    expect(credit_note.refund_amount_cents).to eq(refund_amount_cents)
    expect(credit_note.balance_amount_cents).to eq(credit_amount_cents)
  end

  context "with pay-in-advance subscription" do
    context "when terminating with default behaviors" do
      it "creates credit note for unconsumed subscription fee and generates invoice" do
        create_subscription
        expect_pay_in_advance_to_be_billed

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription)

        expect_subscription_to_be_terminated
        expect_credit_note_to_be_created

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(2)
        expect(billed_invoice.status).to eq("finalized")
        expect(billed_invoice.sub_total_excluding_taxes_amount_cents).to eq(50_00)
        expect(billed_invoice.taxes_amount_cents).to eq(10_00)
        expect(billed_invoice.credit_notes_amount_cents).to eq(30_00)
        expect(billed_invoice.total_amount_cents).to eq(30_00)

        expect_charge_fees_to_be_billed

        expect(credit_note.reload.balance_amount_cents).to eq(0)
      end
    end

    context "when terminating with `on_termination_credit_note=refund`" do
      it "creates credit note for unconsumed subscription fee", :premium do
        create_subscription
        expect_pay_in_advance_to_be_billed

        add_events_to_subscription

        create_payment(customer, subscription_invoice, 75_00)

        terminate_subscription_without_jobs(subscription, {on_termination_credit_note: "refund"})

        expect_subscription_to_be_terminated(on_termination_credit_note: "refund")

        # We started on the 8th and terminated on the 21st, so we have:
        # - 14 days of used subscription (60 euros)
        # - 7 days of unused subscription (30 euros)
        # Since we paid 75 euros, we will refund 15 euros and credit 15 euros.
        expect_credit_note_to_be_created(refund_amount_cents: 15_00)

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(2)
        expect(billed_invoice.status).to eq("finalized")
        expect(billed_invoice.sub_total_excluding_taxes_amount_cents).to eq(50_00)
        expect(billed_invoice.taxes_amount_cents).to eq(10_00)
        expect(billed_invoice.credit_notes_amount_cents).to eq(15_00)
        expect(billed_invoice.total_amount_cents).to eq(45_00)

        expect_charge_fees_to_be_billed

        expect(credit_note.reload.balance_amount_cents).to eq(0)
      end
    end

    context "when terminating with `on_termination_credit_note=skip`" do
      it "skips credit note creation for unconsumed subscription fee" do
        create_subscription
        expect_pay_in_advance_to_be_billed

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription, {on_termination_credit_note: "skip"})

        expect_subscription_to_be_terminated(on_termination_credit_note: "skip")

        expect(subscription_invoice.credit_notes.count).to eq(0)

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(2)
        expect(billed_invoice.status).to eq("finalized")
        expect(billed_invoice.sub_total_excluding_taxes_amount_cents).to eq(50_00)
        expect(billed_invoice.taxes_amount_cents).to eq(10_00)
        expect(billed_invoice.credit_notes_amount_cents).to eq(0)
        expect(billed_invoice.total_amount_cents).to eq(60_00)
      end
    end

    context "when terminating with `on_termination_invoice=skip`" do
      it "skips invoice creation for charge usage" do
        create_subscription
        expect_pay_in_advance_to_be_billed

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription, {on_termination_invoice: "skip"})

        expect_subscription_to_be_terminated(on_termination_invoice: "skip")
        expect_credit_note_to_be_created

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(1)
      end
    end

    context "when subscription is terminated on the same day it was created" do
      let(:termination_date) { subscription_date + 12.hours }
      let(:events_date) { subscription_date + 5.hours }

      it "handles same-day termination correctly" do
        create_subscription
        expect_pay_in_advance_to_be_billed

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription)

        expect(subscription.status).to eq("terminated")
        expect(subscription.on_termination_credit_note).to eq("credit")

        # (20 unused days = 20 / 28 * 100 = 71.43 euro) + 20% tax = 85.71 euro
        credit_note = subscription_invoice.credit_notes.sole

        # 7142.85714 rounded to 7143, then AdjustAmountsWithRoundingService subtracts 1
        expect(credit_note.items.sum(&:amount_cents)).to eq 71_43
        expect(credit_note).to have_attributes(
          sub_total_excluding_taxes_amount_cents: 71_43,
          taxes_amount_cents: 14_29,
          credit_amount_cents: 85_72,
          balance_amount_cents: 85_72,
          total_amount_cents: 85_72
        )
        expect(credit_note.items.sum(&:amount_cents) + credit_note.applied_taxes.sum(:amount_cents)).to eq(credit_note.total_amount_cents)

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(2)
        expect(billed_invoice.status).to eq("finalized")

        # 50 euro charge fee
        expect(billed_invoice.sub_total_excluding_taxes_amount_cents).to eq(50_00)
        expect(billed_invoice.taxes_amount_cents).to eq(10_00)
        expect(billed_invoice.credit_notes_amount_cents).to eq(60_00)
        expect(billed_invoice.total_amount_cents).to eq(0)

        expect_charge_fees_to_be_billed
        expect(credit_note.reload.balance_amount_cents).to eq(25_72) # 71_43 + 14_29 - 60
      end
    end

    context "when terminating pending subscription" do
      it "cancels the subscription and ignores credit note parameter" do
        create_subscription(subscription_at: 5.days.from_now)

        expect(subscription.status).to eq("pending")
        expect(subscription_invoice).to be_nil

        terminate_subscription_without_jobs(subscription, {status: "pending", on_termination_credit_note: "credit"})

        expect(response).to have_http_status(:ok)

        expect(subscription.reload.status).to eq("canceled")
        expect(subscription.on_termination_credit_note).to be_nil
        expect(subscription.canceled_at).to be_present
      end
    end
  end

  context "with pay-in-arrears subscription" do
    let(:plan) { create(:plan, organization:, amount_cents: 100_00) }

    context "when trying to set on_termination_credit_note parameter" do
      it "ignores the parameter since pay-in-arrears plans don't generate credit notes" do
        create_subscription

        expect(subscription.status).to eq("active")
        expect(subscription_invoice).to be_nil

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription, {on_termination_credit_note: "credit"})

        expect(subscription.status).to eq("terminated")
        expect(subscription.on_termination_credit_note).to be_nil

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(1)
        expect(billed_invoice.status).to eq("finalized")

        # 50 euro subscription fee + 50 euro charge fee = 100 euro
        expect(billed_invoice.sub_total_excluding_taxes_amount_cents).to eq(100_00)
        expect(billed_invoice.taxes_amount_cents).to eq(20_00)
        expect(billed_invoice.credit_notes_amount_cents).to eq(0)
        expect(billed_invoice.total_amount_cents).to eq(120_00)

        subscription_fee = billed_invoice.fees.subscription.sole
        expect(subscription_fee).to be_present
        expect(subscription_fee.amount_cents).to eq(50_00)
        expect(subscription_fee.taxes_amount_cents).to eq(10_00)

        expect_charge_fees_to_be_billed
      end
    end

    context "when terminating with `on_termination_invoice=skip`" do
      it "skips invoice creation for charge usage" do
        create_subscription

        add_events_to_subscription

        terminate_subscription_without_jobs(subscription, {on_termination_invoice: "skip"})

        expect_subscription_to_be_terminated(on_termination_credit_note: nil, on_termination_invoice: "skip")

        perform_termination_jobs

        expect(subscription.invoices.count).to eq(0)
      end
    end
  end

  context "when the parameters are invalid" do
    it "returns a validation error" do
      create_subscription

      # when the on_termination_credit_note is invalid
      terminate_subscription_without_jobs(subscription, {on_termination_credit_note: "invalid"}, raise_on_error: false)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(
        {code: "validation_errors", error: "Unprocessable Entity", error_details: {on_termination_credit_note: ["invalid_value"]}, status: 422}
      )

      # when the on_termination_invoice is invalid
      terminate_subscription_without_jobs(subscription, {on_termination_invoice: "invalid"}, raise_on_error: false)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(
        {code: "validation_errors", error: "Unprocessable Entity", error_details: {on_termination_invoice: ["invalid_value"]}, status: 422}
      )

      # when the subscription is not found
      delete_with_token(organization, "/api/v1/subscriptions/#{SecureRandom.uuid}")

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(
        {code: "subscription_not_found", error: "Not Found", status: 404}
      )
    end
  end
end
