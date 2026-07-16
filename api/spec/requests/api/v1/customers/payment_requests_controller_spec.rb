# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::PaymentRequestsController do
  describe "GET /api/v1/customers/:external_id/payment_requests" do
    include_examples "a payment request index endpoint" do
      subject { get_with_token(organization, "/api/v1/customers/#{external_id}/payment_requests", params) }

      let(:external_id) { customer.external_id }

      context "with unknown customer" do
        let(:external_id) { SecureRandom.uuid }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end

      context "with customer from another organization" do
        let(:customer) { create(:customer) }

        it "returns a not found error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end
    end
  end
end
