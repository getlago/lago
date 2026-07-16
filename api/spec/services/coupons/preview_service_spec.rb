# frozen_string_literal: true

require "rails_helper"

RSpec.describe Coupons::PreviewService do
  subject(:preview_service) { described_class.new(invoice:, applied_coupons:) }

  let(:invoice) do
    build(
      :invoice,
      fees_amount_cents: 100,
      sub_total_excluding_taxes_amount_cents: 100,
      currency: "EUR",
      customer: subscription.customer
    )
  end

  let(:subscription) do
    build(
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
    let(:fee) { build(:fee, amount_cents: 100, invoice:, subscription:) }
    let(:applied_coupon) do
      build(
        :applied_coupon,
        customer: subscription.customer,
        amount_cents: 10,
        amount_currency: plan.amount_currency
      )
    end
    let(:coupon_latest) { build(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }
    let(:applied_coupon_latest) do
      build(
        :applied_coupon,
        coupon: coupon_latest,
        customer: subscription.customer,
        percentage_rate: 20.00
      )
    end
    let(:applied_coupons) do
      [
        applied_coupon,
        applied_coupon_latest
      ]
    end

    let(:plan) { create(:plan, interval: "monthly") }

    before do
      invoice.subscriptions = [subscription]
      invoice.fees = [fee]
      applied_coupon
      applied_coupon_latest
    end

    it "updates the invoice accordingly" do
      result = preview_service.call

      expect(result).to be_success
      expect(result.invoice.coupons_amount_cents).to eq(28)
      expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(72)
      expect(result.invoice.credits.length).to eq(2)
    end

    context "when first coupon covers the invoice" do
      let(:invoice) do
        build(
          :invoice,
          fees_amount_cents: 5,
          sub_total_excluding_taxes_amount_cents: 5,
          currency: "EUR",
          customer: subscription.customer
        )
      end

      before { fee.amount_cents = 5 }

      it "updates the invoice accordingly and spends only the first coupon" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(5)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(0)
        expect(result.invoice.credits.length).to eq(1)
      end
    end

    context "when both coupons are fixed amount" do
      let(:coupon_latest) { build(:coupon, coupon_type: "fixed_amount") }
      let(:applied_coupon_latest) do
        create(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency
        )
      end

      it "updates the invoice accordingly" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(30)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(70)
        expect(result.invoice.credits.length).to eq(2)
      end
    end

    context "when both coupons are percentage" do
      let(:coupon) { build(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }
      let(:applied_coupon) do
        build(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          percentage_rate: 15.00
        )
      end

      it "updates the invoice accordingly" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(32)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(68)
        expect(result.invoice.credits.length).to eq(2)
      end
    end

    context "when coupon has a difference currency" do
      let(:applied_coupons) { [applied_coupon] }
      let(:applied_coupon) do
        build(
          :applied_coupon,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: "NOK"
        )
      end

      it "ignores the coupon" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.credits.length).to be_zero
      end
    end

    context "when both coupons have plan limitations which are not applicable" do
      let(:coupon) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { build(:coupon_plan, coupon:, plan: create(:plan)) }
      let(:applied_coupon) do
        build(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { build(:coupon_plan, coupon: coupon_latest, plan: create(:plan)) }
      let(:applied_coupon_latest) do
        build(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
      end

      it "ignores coupons" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(0)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(100)
        expect(result.invoice.credits.length).to be_zero
      end
    end

    context "when only one coupon is applicable due to plan limitations" do
      let(:coupon) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { build(:coupon_plan, coupon:, plan: create(:plan)) }
      let(:applied_coupon) do
        build(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { build(:coupon_plan, coupon: coupon_latest, plan:) }
      let(:applied_coupon_latest) do
        build(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
        coupon.plans = []
        coupon_latest.plans = [plan]
      end

      it "ignores only one coupon and applies the other one" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(20)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(80)
        expect(result.invoice.credits.length).to eq(1)
      end
    end

    context "when both coupons are applicable due to plan limitations" do
      let(:coupon) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan) { build(:coupon_plan, coupon:, plan:) }
      let(:applied_coupon) do
        build(
          :applied_coupon,
          coupon:,
          customer: subscription.customer,
          amount_cents: 10,
          amount_currency: plan.amount_currency
        )
      end
      let(:coupon_latest) { build(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
      let(:coupon_plan_latest) { build(:coupon_plan, coupon: coupon_latest, plan:) }
      let(:applied_coupon_latest) do
        build(
          :applied_coupon,
          coupon: coupon_latest,
          customer: subscription.customer,
          amount_cents: 20,
          amount_currency: plan.amount_currency
        )
      end

      before do
        coupon_plan
        coupon_plan_latest
        coupon.plans = [plan]
        coupon_latest.plans = [plan]
      end

      it "applies two coupons" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.coupons_amount_cents).to eq(30)
        expect(result.invoice.sub_total_excluding_taxes_amount_cents).to eq(70)
        expect(result.invoice.credits.length).to eq(2)
      end
    end
  end
end
