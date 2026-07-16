# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCoupons::AmountService do
  subject(:amount_service) do
    described_class.new(applied_coupon:, base_amount_cents:)
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:base_amount_cents) { 300 }
  let(:coupon) { create(:coupon, organization:) }
  let(:applied_coupon) { create(:applied_coupon, amount_cents: 12, coupon:, customer:) }

  describe "call" do
    it "calculates amount" do
      result = amount_service.call

      expect(result).to be_success
      expect(result.amount).to eq(12)
    end

    context "when base_amount_cents is equal to 0" do
      let(:base_amount_cents) { 0 }

      it "limits the amount to the invoice amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(0)
      end
    end

    context "when coupon amount is higher than invoice amount" do
      let(:base_amount_cents) { 6 }

      it "limits the amount to the invoice amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(6)
      end
    end

    context "when coupon is partially used" do
      before do
        create(
          :credit,
          applied_coupon:,
          amount_cents: 6
        )
      end

      it "applies the remaining amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(6)
      end
    end

    context "when coupon is percentage" do
      let(:coupon) { create(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }

      let(:applied_coupon) do
        create(:applied_coupon, coupon:, percentage_rate: 20.00)
      end

      it "calculates amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(60)
      end
    end

    context "when coupon is recurring and fixed amount" do
      let(:coupon) { create(:coupon, frequency: "recurring", frequency_duration: 3) }

      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          frequency: "recurring",
          frequency_duration: 3,
          frequency_duration_remaining: 3,
          amount_cents: 12
        )
      end

      it "calculates amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(12)
      end

      context "when coupon amount is higher than invoice amount" do
        let(:base_amount_cents) { 6 }

        it "limits the amount to the invoice amount" do
          result = amount_service.call

          expect(result).to be_success
          expect(result.amount).to eq(6)
        end
      end
    end

    context "when coupon is forever and fixed amount" do
      let(:coupon) { create(:coupon, frequency: "forever", frequency_duration: 0) }

      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          frequency: "forever",
          frequency_duration: 0,
          frequency_duration_remaining: 0,
          amount_cents: 12
        )
      end

      it "calculates amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(12)
      end

      context "when coupon amount is higher than invoice amount" do
        let(:base_amount_cents) { 6 }

        it "limits the amount to the invoice amount" do
          result = amount_service.call

          expect(result).to be_success
          expect(result.amount).to eq(6)
        end
      end
    end

    context "when coupon is recurring and percentage" do
      let(:coupon) do
        create(:coupon, frequency: "recurring", frequency_duration: 3, coupon_type: "percentage", percentage_rate: 10)
      end

      let(:applied_coupon) do
        create(
          :applied_coupon,
          coupon:,
          frequency: "recurring",
          frequency_duration: 3,
          frequency_duration_remaining: 3,
          percentage_rate: 20.00
        )
      end

      it "calculates amount" do
        result = amount_service.call

        expect(result).to be_success
        expect(result.amount).to eq(60)
      end
    end
  end
end
