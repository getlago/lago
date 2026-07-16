# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::AppliedCouponsController, :bullet do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  describe "POST /api/v1/applied_coupons" do
    subject do
      post_with_token(organization, "/api/v1/applied_coupons", {applied_coupon: params})
    end

    let(:params) do
      {
        external_customer_id: customer.external_id,
        coupon_code: coupon.code
      }
    end

    let(:coupon) { create(:coupon, organization:) }

    before { create(:subscription, customer:) }

    include_examples "requires API permission", "applied_coupon", "write"

    it "returns a success" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:applied_coupon][:lago_id]).to be_present
      expect(json[:applied_coupon][:lago_coupon_id]).to eq(coupon.id)
      expect(json[:applied_coupon][:lago_customer_id]).to eq(customer.id)
      expect(json[:applied_coupon][:external_customer_id]).to eq(customer.external_id)
      expect(json[:applied_coupon][:amount_cents]).to eq(coupon.amount_cents)
      expect(json[:applied_coupon][:amount_currency]).to eq(coupon.amount_currency)
      expect(json[:applied_coupon][:expiration_at]).to be_nil
      expect(json[:applied_coupon][:created_at]).to be_present
      expect(json[:applied_coupon][:terminated_at]).to be_nil
    end

    context "with invalid params" do
      let(:params) do
        {name: "Foo Bar"}
      end

      it "returns an unprocessable_entity" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/applied_coupons" do
    include_examples "a applied coupon index endpoint" do
      subject { get_with_token(organization, "/api/v1/applied_coupons", params) }

      context "with external_customer_id filter" do
        let(:params) { {external_customer_id: customer.external_id} }

        let(:other_customer) { create(:customer, organization:) }
        let(:other_customer_applied_coupon) do
          create(:applied_coupon, customer: other_customer, coupon: coupon_1)
        end

        before { other_customer_applied_coupon }

        it "returns only the applied coupons for the specified customer" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:applied_coupons].count).to eq(2)
          expect(json[:applied_coupons].pluck(:lago_id)).to match_array([applied_coupon_1.id, applied_coupon_2.id])
        end

        context "when no applied coupons match the external_customer_id" do
          let(:params) { {external_customer_id: "non_existent_id"} }

          it "returns an empty array" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:applied_coupons]).to be_empty
          end
        end
      end
    end
  end
end
