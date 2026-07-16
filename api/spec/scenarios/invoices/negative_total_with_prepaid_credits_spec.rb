# frozen_string_literal: true

require "rails_helper"

# This test verifies that prepaid credits are correctly capped to the invoice total
# when fees have fractional amounts that round differently at the fee vs invoice level.
#
# The bug occurred because the prepaid credit cap calculation used precise tax amounts
# while the invoice total used rounded amounts, potentially causing negative totals.
#
# SCENARIO 1: Mixed zero and non-zero amount fees
# ═══════════════════════════════════════════════════════════════════════════════════
#
#   FEES (with 40% tax)                              INVOICE
#   ┌─────────────────────────────────┐
#   │ 6× small fees                   │              ┌─────────────────────────┐
#   │   amount_cents: 0               │              │ fees_amount: 2          │
#   │   precise_amount: 0.4           │              │ taxes_amount: 1         │
#   │   taxes_precise: 0.16           │──────────────│ total: 3                │
#   │   cap per fee: 0 + 0.16 = 0.16  │              │                         │
#   └─────────────────────────────────┘              │                         │
#   ┌─────────────────────────────────┐              │                         │
#   │ 2× large fees                   │              │                         │
#   │   amount_cents: 1               │──────────────│                         │
#   │   precise_amount: 1.0           │              └─────────────────────────┘
#   │   taxes_precise: 0.4            │
#   │   cap per fee: 1 + 0.4 = 1.4    │
#   └─────────────────────────────────┘
#
#   Old uncapped calculation:  6×0.16 + 2×1.4 = 3.76 → rounds to 4 (exceeds total!)
#   Fixed capped calculation:  min(sum of caps, invoice total) = 3
#
# SCENARIO 2: Identical fees with fractional precise amounts
# ═══════════════════════════════════════════════════════════════════════════════════
#
#   FEES (with 40% tax)                              INVOICE
#   ┌─────────────────────────────────┐
#   │ 8× identical fees               │              ┌─────────────────────────┐
#   │   amount_cents: 1               │              │ fees_amount: 8          │
#   │   precise_amount: 1.4           │──────────────│ taxes_amount: 3         │
#   │   taxes_precise: 0.56           │              │ total: 11               │
#   │   cap per fee: 1 + 0.56 = 1.56  │              │                         │
#   └─────────────────────────────────┘              └─────────────────────────┘
#
#   Old uncapped calculation:  8×1.56 = 12.48 → rounds to 12 (exceeds total!)
#   Fixed capped calculation:  min(sum of caps, invoice total) = 11
#
describe "Prepaid credits capping with fractional fee amounts", :premium do
  let(:organization) { create(:organization, :with_static_values, webhook_url: nil) }
  let(:customer) { create(:customer, :with_static_values, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 0) }
  let(:tax) { create(:tax, rate: 40, organization:) }
  let(:external_subscription_id) { SecureRandom.uuid }

  context "with mixed zero and non-zero amount fees" do
    before do
      (1..6).each do |i|
        metric = create(:billable_metric, organization:, code: "small_metric_#{i}")
        charge = create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "0.004"})
        create(:charge_applied_tax, charge:, tax:)
      end

      (1..2).each do |i|
        metric = create(:billable_metric, organization:, code: "large_metric_#{i}")
        charge = create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "0.01"})
        create(:charge_applied_tax, charge:, tax:)
      end
    end

    it "caps prepaid credits at invoice total of 3" do
      travel_to Time.zone.local(2025, 1, 1, 0, 0, 0)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: external_subscription_id,
        plan_code: plan.code,
        billing_time: "anniversary"
      })

      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        granted_credits: "100",
        invoice_requires_successful_payment: false
      }, as: :model)

      (1..6).each do |i|
        create_event({
          code: "small_metric_#{i}",
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {}
        })
      end

      (1..2).each do |i|
        create_event({
          code: "large_metric_#{i}",
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {}
        })
      end

      travel_to Time.zone.local(2025, 2, 1, 0, 0, 0)
      perform_billing

      invoice = customer.invoices.where(invoice_type: :subscription).sole

      small_fees = invoice.fees.charge.where(amount_cents: 0)
      large_fees = invoice.fees.charge.where("amount_cents > 0")

      expect(small_fees.count).to eq(6)
      expect(large_fees.count).to eq(2)

      small_fees.each do |fee|
        expect(fee.amount_cents).to eq(0)
        expect(fee.precise_amount_cents).to eq(0.4)
        expect(fee.taxes_amount_cents).to eq(0)
        expect(fee.taxes_precise_amount_cents).to eq(0.16)
      end

      large_fees.each do |fee|
        expect(fee.amount_cents).to eq(1)
        expect(fee.precise_amount_cents).to eq(1.0)
        expect(fee.taxes_amount_cents).to eq(0)
        expect(fee.taxes_precise_amount_cents).to eq(0.4)
      end

      expect(invoice.fees_amount_cents).to eq(2)
      expect(invoice.taxes_amount_cents).to eq(1)
      expect(invoice.sub_total_including_taxes_amount_cents).to eq(3)

      expect(invoice.prepaid_credit_amount_cents).to eq(3)
      expect(invoice.total_amount_cents).to eq(0)

      expect(wallet.reload.balance_cents).to eq(9997)
    end
  end

  context "with identical fees having fractional precise amounts" do
    before do
      (1..8).each do |i|
        metric = create(:billable_metric, organization:, code: "metric_#{i}")
        charge = create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "0.014"})
        create(:charge_applied_tax, charge:, tax:)
      end
    end

    it "caps prepaid credits at invoice total of 11" do
      travel_to Time.zone.local(2025, 1, 1, 0, 0, 0)

      create_subscription({
        external_customer_id: customer.external_id,
        external_id: external_subscription_id,
        plan_code: plan.code,
        billing_time: "anniversary"
      })

      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        currency: "EUR",
        granted_credits: "100",
        invoice_requires_successful_payment: false
      }, as: :model)

      (1..8).each do |i|
        create_event({
          code: "metric_#{i}",
          external_customer_id: customer.external_id,
          external_subscription_id: external_subscription_id,
          properties: {}
        })
      end

      travel_to Time.zone.local(2025, 2, 1, 0, 0, 0)
      perform_billing

      invoice = customer.invoices.where(invoice_type: :subscription).sole

      expect(invoice.fees.charge.count).to eq(8)

      invoice.fees.charge.each do |fee|
        expect(fee.amount_cents).to eq(1)
        expect(fee.precise_amount_cents).to eq(1.4)
        expect(fee.taxes_amount_cents).to eq(0)
        expect(fee.taxes_precise_amount_cents).to eq(0.56)
      end

      expect(invoice.fees_amount_cents).to eq(8)
      expect(invoice.taxes_amount_cents).to eq(3)
      expect(invoice.sub_total_including_taxes_amount_cents).to eq(11)

      expect(invoice.prepaid_credit_amount_cents).to eq(11)
      expect(invoice.total_amount_cents).to eq(0)

      expect(wallet.reload.balance_cents).to eq(9989)
    end
  end
end
