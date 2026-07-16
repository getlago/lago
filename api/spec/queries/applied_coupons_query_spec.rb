# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCouponsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:organization) { create(:organization) }
  let(:pagination) { nil }
  let(:filters) { {} }

  let(:customer_1) { create(:customer, organization:) }
  let(:coupon_1) { create(:coupon, organization:) }
  let(:customer_2) { create(:customer, organization:) }
  let(:coupon_2) { create(:coupon, organization:) }

  let!(:applied_coupon_1) { create(:applied_coupon, coupon: coupon_1, customer: customer_1) }
  let!(:applied_coupon_2) { create(:applied_coupon, coupon: coupon_2, customer: customer_2) }

  it "returns a list of applied_coupons" do
    expect(result).to be_success
    expect(result.applied_coupons.count).to eq(2)
    expect(result.applied_coupons).to eq([applied_coupon_2, applied_coupon_1])
  end

  context "when applied coupons have the same values for the ordering criteria" do
    let!(:applied_coupon_3) do
      create(
        :applied_coupon,
        coupon: coupon_2,
        customer: customer_2,
        id: "00000000-0000-0000-0000-000000000000",
        created_at: applied_coupon_2.created_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(3)
      expect(result.applied_coupons).to eq([applied_coupon_3, applied_coupon_2, applied_coupon_1])
    end
  end

  context "when customer is deleted" do
    let(:customer_1) { create(:customer, :deleted, organization:) }

    it "filters the applied_coupons" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(1)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 10} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(0)
      expect(result.applied_coupons.current_page).to eq(2)
    end
  end

  context "with customer filter" do
    let(:filters) { {external_customer_id: customer_1.external_id} }

    it "applies the filter" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(1)
      expect(result.applied_coupons).to eq([applied_coupon_1])
    end
  end

  context "with status filter" do
    let(:filters) { {status: "terminated"} }

    it "applies the filter" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(0)
    end
  end

  context "with coupon code filter" do
    let(:filters) { {coupon_code: [coupon_2.code]} }

    it "applies the filter for multiple codes" do
      expect(result).to be_success
      expect(result.applied_coupons.count).to eq(1)
      expect(result.applied_coupons).to match_array([applied_coupon_2])
    end

    context "when the coupon is deleted" do
      let(:coupon_2) { create(:coupon, :deleted, organization:) }
      let!(:applied_coupon_2) do
        create(
          :applied_coupon,
          :terminated,
          customer: customer_2,
          coupon: coupon_2
        )
      end

      it "returns the applied coupon" do
        expect(result).to be_success
        expect(result.applied_coupons.count).to eq(1)
        expect(result.applied_coupons).to match_array([applied_coupon_2])
      end
    end

    context "when coupon code is not found" do
      let(:filters) { {coupon_code: "nonexistent"} }

      it "returns an empty list" do
        expect(result).to be_success
        expect(result.applied_coupons.count).to eq(0)
      end
    end
  end
end
