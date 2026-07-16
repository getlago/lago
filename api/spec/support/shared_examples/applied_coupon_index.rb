# frozen_string_literal: true

RSpec.shared_examples "a applied coupon index endpoint" do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:params) { {} }

  let(:coupon_1) { create(:coupon, coupon_type: "fixed_amount", organization:) }
  let(:coupon_2) { create(:coupon, coupon_type: "fixed_amount", organization:) }

  let!(:applied_coupon_1) do
    create(
      :applied_coupon,
      customer:,
      coupon: coupon_1,
      amount_cents: 10,
      amount_currency: customer.currency
    )
  end
  let!(:applied_coupon_2) do
    create(
      :applied_coupon,
      customer: customer,
      coupon: coupon_2,
      amount_cents: 10,
      amount_currency: customer.currency
    )
  end

  before do
    create(:credit, applied_coupon: applied_coupon_1, amount_cents: 2, amount_currency: customer.currency)
  end

  include_examples "requires API permission", "applied_coupon", "read"

  it "returns applied coupons" do
    subject

    expect(response).to have_http_status(:success)
    expect(json[:applied_coupons].count).to eq(2)
    expect(json[:applied_coupons].first[:lago_id]).to eq(applied_coupon_2.id)
    expect(json[:applied_coupons].last[:lago_id]).to eq(applied_coupon_1.id)
    expect(json[:applied_coupons].last[:amount_cents]).to eq(applied_coupon_1.amount_cents)
    expect(json[:applied_coupons].last[:amount_cents_remaining]).to eq(8)

    expect(json[:meta][:current_page]).to eq(1)
    expect(json[:meta][:next_page]).to eq(nil)
    expect(json[:meta][:prev_page]).to eq(nil)
    expect(json[:meta][:total_pages]).to eq(1)
    expect(json[:meta][:total_count]).to eq(2)
  end

  context "with pagination" do
    let(:params) { {page: 2, per_page: 1} }

    it "returns paginated applied coupons" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:applied_coupons].count).to eq(1)
      expect(json[:applied_coupons].first[:lago_id]).to eq(applied_coupon_1.id)

      expect(json[:meta][:current_page]).to eq(2)
      expect(json[:meta][:next_page]).to eq(nil)
      expect(json[:meta][:prev_page]).to eq(1)
      expect(json[:meta][:total_pages]).to eq(2)
      expect(json[:meta][:total_count]).to eq(2)
    end
  end

  context "with status filter" do
    let(:params) { {status: "active"} }

    it "returns only the applied coupons with the specified status" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:applied_coupons].count).to eq(2)
      expect(json[:applied_coupons].first[:lago_id]).to eq(applied_coupon_2.id)
      expect(json[:applied_coupons].last[:lago_id]).to eq(applied_coupon_1.id)
    end

    context "when no applied coupons match the status" do
      let(:params) { {status: "terminated"} }

      it "returns an empty array" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:applied_coupons]).to be_empty
      end
    end
  end

  context "with coupon_code filter" do
    context "when coupon_code fitlering is an array" do
      let(:params) { {coupon_code: [coupon_1.code]} }

      it "returns only the applied coupons for the specified coupon code" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:applied_coupons].count).to eq(1)
        expect(json[:applied_coupons].first[:lago_id]).to eq(applied_coupon_1.id)
      end

      context "when the coupon is deleted" do
        let(:coupon_1) { create(:coupon, :deleted, organization:) }
        let!(:applied_coupon_1) do
          create(
            :applied_coupon,
            :terminated,
            customer:,
            coupon: coupon_1,
            amount_cents: 10,
            amount_currency: customer.currency
          )
        end

        it "returns the applied coupon" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:applied_coupons].count).to eq(1)
          expect(json[:applied_coupons].first[:lago_id]).to eq(applied_coupon_1.id)
        end
      end
    end

    context "when no applied coupons match the coupon code" do
      let(:params) { {coupon_code: ["non_existent_code"]} }

      it "returns an empty array" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:applied_coupons]).to be_empty
      end
    end
  end

  context "when the coupon is deleted" do
    let(:coupon_1) { create(:coupon, :deleted, organization:) }
    let!(:applied_coupon_1) do
      create(
        :applied_coupon,
        :terminated,
        customer:,
        coupon: coupon_1,
        amount_cents: 10,
        amount_currency: customer.currency
      )
    end

    it "returns the applied coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:applied_coupons].count).to eq(2)
      expect(json[:applied_coupons].last[:lago_id]).to eq(applied_coupon_1.id)
      expect(json[:applied_coupons].last[:coupon_code]).to eq(coupon_1.code)
      expect(json[:applied_coupons].last[:coupon_name]).to eq(coupon_1.name)
      expect(json[:applied_coupons].last[:coupon_status]).to eq(coupon_1.status)
      expect(json[:applied_coupons].last[:coupon_deleted_at]).to eq(coupon_1.deleted_at.iso8601)
    end
  end
end
