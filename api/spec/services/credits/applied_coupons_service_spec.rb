# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credits::AppliedCouponsService do
  subject(:credit_service) { described_class.new(invoice:) }

  let(:invoice) do
    create(
      :invoice,
      fees_amount_cents: 100,
      sub_total_excluding_taxes_amount_cents: 100,
      currency: "EUR",
      customer: subscription.customer
    )
  end

  let(:subscription) do
    create(
      :subscription,
      plan:,
      billing_time: :calendar,
      subscription_at: started_at,
      started_at:,
      created_at:,
      status: :active
    )
  end
  let(:started_at) { Time.zone.now - 2.years }
  let(:created_at) { started_at }

  describe "#call" do
    let(:timestamp) { Time.zone.now.beginning_of_month }
    let(:fee) { create(:fee, amount_cents: 100, invoice:, subscription:) }
    let(:applied_coupon) do
      create(
        :applied_coupon,
        customer: subscription.customer,
        amount_cents: 10,
        amount_currency: plan.amount_currency
      )
    end
    let(:coupon_latest) { create(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }
    let(:applied_coupon_latest) do
      create(
        :applied_coupon,
        coupon: coupon_latest,
        customer: subscription.customer,
        percentage_rate: 20.00,
        created_at: applied_coupon.created_at + 1.day
      )
    end

    let(:plan) { create(:plan, interval: "monthly") }

    before do
      create(:invoice_subscription, invoice:, subscription:)
      fee
      applied_coupon
      applied_coupon_latest
    end

    it "updates the invoice accordingly" do
      result = credit_service.call

      expect(result).to be_success
      expect(result.invoice.coupons_amount_cents).to eq(28)
      expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(72)
      expect(result.invoice.credits.count).to eq(2)
    end

    context "when first coupon covers the invoice" do
      let(:invoice) do
        create(
          :invoice,
          fees_amount_cents: 5,
          sub_total_excluding_taxes_amount_cents: 5,
          currency: "EUR",
          customer: subscription.customer
        )
      end

      before { fee.update!(amount_cents: 5) }

      it "updates the invoice accordingly and spends only the first coupon" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(5)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(0)
        expect(result.invoice.credits.count).to eq(1)
      end
    end

    context "when both coupons are fixed amount" do
      let(:coupon_latest) { create(:coupon, coupon_type: "fixed_amount") }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 1.day
        )
      end

      it "updates the invoice accordingly" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(30)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(70)
        expect(result.invoice.credits.count).to eq(2)
      end
    end

    context "when both coupons are percentage" do
      let(:coupon) { create(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          percentage_rate: 15.00
        )
      end

      it "updates the invoice accordingly" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(32)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(68)
        expect(result.invoice.credits.count).to eq(2)
      end
    end

    context "when coupon has a difference currency" do
      let(:applied_coupon) do
        create(
          :applied_coupon,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: "NOK"
        )
      end

      before { applied_coupon_latest.update!(status: :terminated) }

      it "ignores the coupon" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.credits.count).to be_zero
      end
    end

    context "when both coupons have plan limitations which are not applicable" do
      let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan: create(:plan)) }
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { create(:coupon_plan, coupon: coupon_latest, plan: create(:plan)) }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 1.day
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
      end

      it "ignores coupons" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(0)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(100)
        expect(result.invoice.credits.count).to be_zero
      end
    end

    context "when only one coupon is applicable due to plan limitations" do
      let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan: create(:plan)) }
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { create(:coupon_plan, coupon: coupon_latest, plan:) }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 1.day
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
      end

      it "ignores only one coupon and applies the other one" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(20)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(80)
        expect(result.invoice.credits.count).to eq(1)
      end
    end

    context "when both coupons are applicable due to plan limitations" do
      let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { create(:coupon_plan, coupon: coupon_latest, plan:) }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 1.day
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
      end

      it "applies two coupons" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(30)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(70)
        expect(result.invoice.credits.count).to eq(2)
      end
    end

    context "when there is combination of coupon limited to plans and coupon limited to billable metrics" do
      let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }
      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 82,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_middle) { create(:coupon, coupon_type: "fixed_amount", limited_billable_metrics: true) }
      let(:billable_metric) { create(:billable_metric, organization: invoice.organization) }
      let(:charge) { create(:standard_charge, billable_metric:) }
      let(:coupon_bm_middle) do
        create(:coupon_billable_metric, coupon: coupon_middle, billable_metric:)
      end
      let(:applied_coupon_middle) do
        create(
          :applied_coupon,
          coupon: coupon_middle,
          customer: subscription.customer,
          amount_cents: 5,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 2.hours
        )
      end
      let(:coupon_latest) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { create(:coupon_plan, coupon: coupon_latest, plan: create(:plan)) }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency,
          created_at: applied_coupon.created_at + 1.day
        )
      end
      let(:fee_middle) do
        create(
          :fee,
          invoice:,
          charge:,
          amount_cents: 12,
          amount_currency: "EUR",
          taxes_amount_cents: 3
        )
      end
      let(:fee) do
        create(
          :fee,
          invoice:,
          subscription:,
          amount_cents: 75,
          amount_currency: "EUR",
          taxes_amount_cents: 5
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
        charge
        coupon_bm_middle
        applied_coupon_middle
        fee_middle
      end

      it "applies two coupons" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(80)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(20)
        expect(result.invoice.credits.count).to eq(2)
      end
    end
  end
end
