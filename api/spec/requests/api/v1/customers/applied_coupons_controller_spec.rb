# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::AppliedCouponsController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:external_id) { customer.external_id }

  describe "GET /api/v1/customers/:external_id/applied_coupons" do
    include_examples "a applied coupon index endpoint" do
      subject { get_with_token(organization, "/api/v1/customers/#{external_id}/applied_coupons", params) }

      let(:external_id) { customer.external_id }

      context "when customer external_id is unknown" do
        let(:external_id) { "unknown" }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
        end
      end

      context "when customer belongs to another organization" do
        let(:customer) { create(:customer) }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe "DELETE /api/v1/customers/:customer_external_id/applied_coupons/:id" do
    subject do
      delete_with_token(
        organization,
        "/api/v1/customers/#{external_id}/applied_coupons/#{identifier}"
      )
    end

    let!(:applied_coupon) { create(:applied_coupon, customer:) }
    let(:external_id) { customer.external_id }
    let(:identifier) { applied_coupon.id }

    include_examples "requires API permission", "applied_coupon", "write"

    it "terminates the applied coupon" do
      expect { subject }
        .to change { applied_coupon.reload.status }.from("active").to("terminated")
    end

    it "returns the applied_coupon" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:applied_coupon][:lago_id]).to eq(applied_coupon.id)
    end

    context "when customer does not exist" do
      let(:external_id) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when applied coupon does not exist" do
      let(:identifier) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when coupon is not applied to customer" do
      let(:other_applied_coupon) { create(:applied_coupon) }
      let(:identifier) { other_applied_coupon.id }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
