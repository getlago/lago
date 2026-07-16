# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ProgressiveBilledAmount do
  subject(:service) { described_class.new(subscription:, timestamp:) }

  let(:timestamp) { Time.current }
  let(:subscription) { create(:subscription, customer_id: customer.id) }
  let(:organization) { subscription.organization }
  let(:customer) { create(:customer) }

  let(:charges_to_datetime) { timestamp + 1.week }
  let(:charges_from_datetime) { timestamp - 1.week }
  let(:invoice_type) { :progressive_billing }

  context "without previous progressive billing invoices" do
    it "returns 0" do
      result = service.call
      expect(result.progressive_billed_amount).to be_zero
      expect(result.total_billed_amount_cents).to be_zero
      expect(result.progressive_billing_invoice).to be_nil
      expect(result.to_credit_amount).to be_zero
      expect(result.invoice_subscriptions).to be_empty
    end
  end

  context "with progressive billing invoice for another subscription" do
    let(:other_subscription) { create(:subscription, customer_id: customer.id) }
    let(:invoice_subscription) { create(:invoice_subscription, subscription: other_subscription, charges_from_datetime:, charges_to_datetime:) }
    let(:other_invoice) { invoice_subscription.invoice }

    before do
      other_invoice.update!(invoice_type:, fees_amount_cents: 20, total_amount_cents: 20)
    end

    it "returns 0" do
      result = service.call
      expect(result.progressive_billed_amount).to be_zero
      expect(result.total_billed_amount_cents).to be_zero
      expect(result.progressive_billing_invoice).to be_nil
      expect(result.to_credit_amount).to be_zero
      expect(result.invoice_subscriptions).to be_empty
    end
  end

  context "with progressive billing invoice for this subscription" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee) { create(:charge_fee, invoice:, subscription:, amount_cents: 20, taxes_amount_cents: 0) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 20, total_amount_cents: 20)
    end

    it "returns the fees_amount_cents from that invoice" do
      result = service.call
      expect(result.progressive_billed_amount).to eq(20)
      expect(result.total_billed_amount_cents).to eq(20)
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.to_credit_amount).to eq(20)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with failed progressive billing invoice for this subscription" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee) { create(:charge_fee, invoice:, subscription:, amount_cents: 20, taxes_amount_cents: 0) }

    before do
      fee
      invoice.update!(invoice_type:, status: :failed, fees_amount_cents: 20, prepaid_credit_amount_cents: 20)
    end

    it "returns the fees_amount_cents from that invoice" do
      result = service.call
      expect(result.progressive_billed_amount).to eq(20)
      expect(result.total_billed_amount_cents).to eq(20)
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.to_credit_amount).to eq(20)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with generating progressive billing invoice for this subscription" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee) { create(:charge_fee, invoice:, subscription:, amount_cents: 20, taxes_amount_cents: 0) }

    before do
      fee
      invoice.update!(invoice_type:, status: :generating, fees_amount_cents: 20, prepaid_credit_amount_cents: 20)
    end

    it "returns 0" do
      result = service.call
      expect(result.progressive_billed_amount).to be_zero
      expect(result.total_billed_amount_cents).to be_zero
      expect(result.progressive_billing_invoice).to be_nil
      expect(result.to_credit_amount).to be_zero
      expect(result.invoice_subscriptions).to be_empty
    end

    context "when passing include_generating_invoices: true" do
      subject(:service) { described_class.new(subscription:, timestamp:, include_generating_invoices: true) }

      it "returns the fees_amount_cents from that invoice" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.total_billed_amount_cents).to eq(20)
        expect(result.progressive_billing_invoice).to eq(invoice)
        expect(result.to_credit_amount).to eq(20)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end
    end
  end

  context "with progressive billing invoice for this subscription in previous period" do
    let(:charges_to_datetime) { timestamp - 1.week }
    let(:charges_from_datetime) { timestamp - 2.weeks }
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }

    before do
      invoice.update!(invoice_type:, fees_amount_cents: 20, prepaid_credit_amount_cents: 20)
    end

    it "returns 0" do
      result = service.call
      expect(result.progressive_billed_amount).to be_zero
      expect(result.total_billed_amount_cents).to be_zero
      expect(result.progressive_billing_invoice).to be_nil
      expect(result.to_credit_amount).to be_zero
      expect(result.invoice_subscriptions).to be_empty
    end
  end

  context "with multiple progressive billing invoice for this subscription" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee1) { create(:charge_fee, invoice:, subscription:, amount_cents: 20, taxes_amount_cents: 0) }
    let(:invoice_subscription2) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice2) { invoice_subscription2.invoice }
    let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, taxes_amount_cents: 0, precise_coupons_amount_cents: 20) }

    before do
      fee1
      fee2
      invoice.update!(invoice_type:, issuing_date: timestamp - 2.days, fees_amount_cents: 20, total_amount_cents: 0, prepaid_credit_amount_cents: 20)
      invoice2.update!(invoice_type:, issuing_date: timestamp - 1.day, fees_amount_cents: 40, total_amount_cents: 10, prepaid_credit_amount_cents: 10)
    end

    it "returns the last issued invoice fees_amount_cents" do
      result = service.call
      expect(result.progressive_billed_amount).to eq(40)
      expect(result.total_billed_amount_cents).to eq(40)
      expect(result.progressive_billing_invoice).to eq(invoice2)
      expect(result.to_credit_amount).to eq(40)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription, invoice_subscription2)
    end
  end

  context "with multiple progressive billing invoice for this subscription and the last one failed" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee1) { create(:charge_fee, invoice:, subscription:, amount_cents: 20, taxes_amount_cents: 0) }
    let(:invoice_subscription2) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice2) { invoice_subscription2.invoice }
    let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, taxes_amount_cents: 0, precise_coupons_amount_cents: 20) }

    before do
      fee1
      fee2
      invoice.update!(invoice_type:, issuing_date: timestamp - 2.days, fees_amount_cents: 20)
      invoice2.update!(invoice_type:, status: :failed, issuing_date: timestamp - 1.day, fees_amount_cents: 40)
    end

    it "returns the last issued invoice fees_amount_cents" do
      result = service.call
      expect(result.progressive_billed_amount).to eq(40)
      expect(result.total_billed_amount_cents).to eq(40)
      expect(result.progressive_billing_invoice).to eq(invoice2)
      expect(result.to_credit_amount).to eq(40)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription, invoice_subscription2)
    end
  end

  context "with progressive billing invoice for this subscription, but it has a credit note" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:credit_note) { create(:credit_note, invoice:, credit_amount_cents:) }

    before do
      invoice.update!(invoice_type:, fees_amount_cents: 20)
      credit_note
    end

    context "when fully credited" do
      let(:credit_amount_cents) { 20 }

      it "returns the fees_amount_cents from that invoice" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.progressive_billing_invoice).to eq(invoice)
        expect(result.to_credit_amount).to eq(0)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end

      context "when credit note is consumed" do
        let(:credit_note) { create(:credit_note, invoice:, credit_amount_cents:, credit_status: :consumed) }

        it "doesn't return amount cents that is fully consumed" do
          result = service.call
          expect(result.progressive_billed_amount).to eq(20)
          expect(result.progressive_billing_invoice).to eq(invoice)
          expect(result.to_credit_amount).to eq(0)
          expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
        end
      end
    end

    context "when partially credited" do
      let(:credit_amount_cents) { 10 }

      it "returns the fees_amount_cents from that invoice" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.progressive_billing_invoice).to eq(invoice)
        expect(result.to_credit_amount).to eq(10)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end
    end
  end

  context "with progressive billing invoice for this subscription, but it has already been applied to an invoice" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:progressive_billing_invoice) { invoice_subscription.invoice }
    let(:other_invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { other_invoice_subscription.invoice }
    let(:progressive_billing_credit) do
      create(:credit,
        invoice:,
        progressive_billing_invoice:,
        amount_cents: amount_to_credit,
        amount_currency: invoice.currency,
        before_taxes: true)
    end

    before do
      progressive_billing_credit
      progressive_billing_invoice.update!(invoice_type:, fees_amount_cents: 20)
    end

    context "when fully credited" do
      let(:amount_to_credit) { 20 }

      it "returns the fees_amount_cents from that invoice" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.progressive_billing_invoice).to eq(progressive_billing_invoice)
        expect(result.to_credit_amount).to eq(0)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end
    end

    context "when partially credited" do
      let(:amount_to_credit) { 10 }

      it "returns the fees_amount_cents from that invoice" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.progressive_billing_invoice).to eq(progressive_billing_invoice)
        expect(result.to_credit_amount).to eq(10)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end
    end

    context "when the invoice using the progressive billing credit is voided" do
      let(:amount_to_credit) { 20 }

      before { invoice.update!(status: :voided) }

      it "does not subtract the voided invoice credit" do
        result = service.call
        expect(result.progressive_billed_amount).to eq(20)
        expect(result.progressive_billing_invoice).to eq(progressive_billing_invoice)
        expect(result.to_credit_amount).to eq(20)
        expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
      end
    end
  end

  context "with progressive billing invoice that has 100% coupon discount" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 100, taxes_amount_cents: 0) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100, coupons_amount_cents: 100, sub_total_excluding_taxes_amount_cents: 0, total_amount_cents: 0)
    end

    it "returns to_credit_amount of 0 when fees are fully discounted" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to be_zero
      expect(result.total_billed_amount_cents).to be_zero
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with progressive billing invoice that has partial coupon discount" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 30, taxes_amount_cents: 14) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100, coupons_amount_cents: 30, sub_total_excluding_taxes_amount_cents: 70, taxes_amount_cents: 14, total_amount_cents: 84)
    end

    it "returns net amount after coupons" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(70)
      expect(result.total_billed_amount_cents).to eq(84)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with multiple progressive billing invoices with coupons" do
    let(:invoice_subscription1) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice1) { invoice_subscription1.invoice }
    let(:invoice_subscription2) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice2) { invoice_subscription2.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee1) { create(:charge_fee, invoice: invoice1, subscription:, charge:, amount_cents: 50, precise_coupons_amount_cents: 10, taxes_amount_cents: 0) }
    let(:fee2) { create(:charge_fee, invoice: invoice2, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 20, taxes_amount_cents: 0) }

    before do
      fee1
      fee2
      invoice1.update!(invoice_type:, issuing_date: timestamp - 2.days, fees_amount_cents: 50, coupons_amount_cents: 10, sub_total_excluding_taxes_amount_cents: 40)
      invoice2.update!(invoice_type:, issuing_date: timestamp - 1.day, fees_amount_cents: 100, coupons_amount_cents: 20, sub_total_excluding_taxes_amount_cents: 80)
    end

    it "returns to_credit_amount from most recent invoice after coupons" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice2)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(80)
      expect(result.total_billed_amount_cents).to eq(120)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription1, invoice_subscription2)
    end
  end

  context "with progressive billing invoice with coupons and existing credits" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 20, taxes_amount_cents: 0) }
    let(:existing_credit) { create(:credit, invoice:, progressive_billing_invoice: invoice, amount_cents: 30) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100, coupons_amount_cents: 20, sub_total_excluding_taxes_amount_cents: 80)
      existing_credit
    end

    it "subtracts existing credits from net amount" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(50)
      expect(result.total_billed_amount_cents).to eq(80)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with progressive billing invoice with coupons and existing credit notes" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 20, taxes_amount_cents: 0) }
    let(:existing_credit_note) { create(:credit_note, invoice:, credit_amount_cents: 20, total_amount_cents: 20, credit_status: :available) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100, coupons_amount_cents: 20, sub_total_excluding_taxes_amount_cents: 80)
      existing_credit_note
    end

    it "subtracts existing credit notes from net amount" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(60)
      expect(result.total_billed_amount_cents).to eq(80)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "when coupons and existing credits would result in negative to_credit_amount" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 60, taxes_amount_cents: 0) }
    let(:existing_credit) { create(:credit, invoice:, progressive_billing_invoice: invoice, amount_cents: 50) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100, coupons_amount_cents: 60, sub_total_excluding_taxes_amount_cents: 40)
      existing_credit
    end

    it "returns 0 instead of negative value" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to be_zero
      expect(result.total_billed_amount_cents).to eq(40)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with progressive billing invoice that has credit notes with different statuses" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:fee) { create(:charge_fee, invoice:, subscription:, amount_cents: 100, taxes_amount_cents: 0) }
    let(:available_credit_note) { create(:credit_note, invoice:, credit_amount_cents: 20, total_amount_cents: 20, credit_status: :available) }
    let(:consumed_credit_note) { create(:credit_note, invoice:, credit_amount_cents: 10, total_amount_cents: 10, credit_status: :consumed) }
    let(:voided_credit_note) { create(:credit_note, invoice:, credit_amount_cents: 15, total_amount_cents: 15, credit_status: :voided) }

    before do
      fee
      invoice.update!(invoice_type:, fees_amount_cents: 100)
      available_credit_note
      consumed_credit_note
      voided_credit_note
    end

    it "subtracts available and consumed credit notes from to_credit_amount" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(70)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end

  context "with multiple progressive billing invoices with same issuing_date" do
    let(:invoice_subscription1) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice1) { invoice_subscription1.invoice }
    let(:invoice_subscription2) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice2) { invoice_subscription2.invoice }
    let(:fee1) { create(:charge_fee, invoice: invoice1, subscription:, amount_cents: 50, taxes_amount_cents: 0) }
    let(:fee2) { create(:charge_fee, invoice: invoice2, subscription:, amount_cents: 100, taxes_amount_cents: 0) }
    let(:same_issuing_date) { timestamp - 1.day }

    before do
      fee1
      fee2
      invoice1.update!(invoice_type:, issuing_date: same_issuing_date, created_at: timestamp - 2.hours, fees_amount_cents: 50)
      invoice2.update!(invoice_type:, issuing_date: same_issuing_date, created_at: timestamp - 1.hour, fees_amount_cents: 100)
    end

    it "returns the most recently created invoice when issuing_dates are the same" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice2)
      expect(result.progressive_billed_amount).to eq(100)
      expect(result.to_credit_amount).to eq(100)
      expect(result.total_billed_amount_cents).to eq(150)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription1, invoice_subscription2)
    end
  end

  context "with progressive billing invoice that has multiple fees with varying coupons" do
    let(:invoice_subscription) { create(:invoice_subscription, subscription:, charges_from_datetime:, charges_to_datetime:) }
    let(:invoice) { invoice_subscription.invoice }
    let(:charge) { create(:standard_charge, plan: subscription.plan) }
    let(:fee1) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 100, precise_coupons_amount_cents: 30, taxes_amount_cents: 0) }
    let(:fee2) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 50, precise_coupons_amount_cents: 10, taxes_amount_cents: 0) }
    let(:fee3) { create(:charge_fee, invoice:, subscription:, charge:, amount_cents: 30, precise_coupons_amount_cents: 0, taxes_amount_cents: 0) }

    before do
      fee1
      fee2
      fee3
      invoice.update!(invoice_type:, fees_amount_cents: 180, coupons_amount_cents: 40, sub_total_excluding_taxes_amount_cents: 140)
    end

    it "correctly calculates total_billed_amount_cents from multiple fees with varying coupons" do
      result = service.call
      expect(result.progressive_billing_invoice).to eq(invoice)
      expect(result.progressive_billed_amount).to eq(180)
      expect(result.to_credit_amount).to eq(140)
      expect(result.total_billed_amount_cents).to eq(140)
      expect(result.invoice_subscriptions).to contain_exactly(invoice_subscription)
    end
  end
end
