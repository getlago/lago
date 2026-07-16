# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::CouponsController do
  let(:organization) { create(:organization) }

  describe "POST /api/v1/coupons" do
    subject { post_with_token(organization, "/api/v1/coupons", {coupon: create_params}) }

    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:expiration_at) { Time.current + 15.days }

    let(:create_params) do
      {
        name: "coupon1",
        code: "coupon1_code",
        coupon_type: "fixed_amount",
        frequency: "once",
        amount_cents: 123,
        amount_currency: "EUR",
        expiration: "time_limit",
        expiration_at:,
        reusable: false,
        applies_to: {
          billable_metric_codes: [billable_metric.code]
        }
      }
    end

    include_examples "requires API permission", "coupon", "write"

    it "creates a coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:coupon][:lago_id]).to be_present
      expect(json[:coupon][:code]).to eq(create_params[:code])
      expect(json[:coupon][:name]).to eq(create_params[:name])
      expect(json[:coupon][:created_at]).to be_present
      expect(json[:coupon][:expiration_at]).to eq(expiration_at.iso8601)
      expect(json[:coupon][:reusable]).to eq(false)
      expect(json[:coupon][:limited_billable_metrics]).to eq(true)
      expect(json[:coupon][:billable_metric_codes].first).to eq(billable_metric.code)
    end
  end

  describe "PUT /api/v1/coupons/:code" do
    subject do
      put_with_token(organization, "/api/v1/coupons/#{coupon_code}", {coupon: update_params})
    end

    let(:coupon) { create(:coupon, organization:) }
    let(:code) { "coupon_code" }
    let(:coupon_code) { coupon.code }
    let(:expiration_at) { Time.current + 15.days }
    let(:update_params) do
      {
        name: "coupon1",
        code:,
        coupon_type: "fixed_amount",
        frequency: "once",
        amount_cents: 123,
        amount_currency: "EUR",
        expiration: "time_limit",
        expiration_at:
      }
    end

    include_examples "requires API permission", "coupon", "write"

    it "updates a coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:coupon][:lago_id]).to eq(coupon.id)
      expect(json[:coupon][:code]).to eq(update_params[:code])
      expect(json[:coupon][:expiration_at]).to eq(expiration_at.iso8601)
    end

    context "when coupon does not exist" do
      let(:coupon_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when coupon code already exists in organization scope (validation error)" do
      let!(:another_coupon) { create(:coupon, organization:) }
      let(:code) { another_coupon.code }

      it "returns unprocessable_entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /api/v1/coupons/:code" do
    subject { get_with_token(organization, "/api/v1/coupons/#{coupon_code}") }

    let(:coupon) { create(:coupon, organization:) }
    let(:coupon_code) { coupon.code }

    include_examples "requires API permission", "coupon", "read"

    it "returns a coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:coupon][:lago_id]).to eq(coupon.id)
      expect(json[:coupon][:code]).to eq(coupon.code)
    end

    context "when coupon does not exist" do
      let(:coupon_code) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/coupons/:code" do
    subject { delete_with_token(organization, "/api/v1/coupons/#{coupon_code}") }

    let!(:coupon) { create(:coupon, organization:) }
    let(:coupon_code) { coupon.code }

    include_examples "requires API permission", "coupon", "write"

    it "deletes a coupon" do
      expect { subject }.to change(Coupon, :count).by(-1)
    end

    it "returns deleted coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:coupon][:lago_id]).to eq(coupon.id)
      expect(json[:coupon][:code]).to eq(coupon.code)
    end

    context "when coupon does not exist" do
      let(:coupon_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/coupons" do
    subject { get_with_token(organization, "/api/v1/coupons", params) }

    let!(:coupon) { create(:coupon, organization:) }
    let(:params) { {} }

    include_examples "requires API permission", "coupon", "read"

    it "returns coupons" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:coupons].count).to eq(1)
      expect(json[:coupons].first[:lago_id]).to eq(coupon.id)
      expect(json[:coupons].first[:code]).to eq(coupon.code)
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      before { create(:coupon, organization:) }

      it "returns coupons with correct meta data" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:coupons].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:next_page]).to eq(2)
        expect(json[:meta][:prev_page]).to eq(nil)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end
end
