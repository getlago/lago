# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::PaymentsController do
  describe "GET /api/v1/customers/:external_id/payments" do
    it_behaves_like "a payment index endpoint" do
      subject { get_with_token(organization, "/api/v1/customers/#{customer.external_id}/payments", params) }

      context "with invalid customer id" do
        subject { get_with_token(organization, "/api/v1/customers/foo/payments", {}) }

        it "returns a 404" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end

      context "with an invoice belonging to a different customer" do
        let(:params) { {invoice_id: invoice.id} }
        let(:invoice) { create(:invoice, organization:) }

        before do
          create(:payment, payable: invoice)
        end

        it "returns an empty result" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:payments]).to be_empty
        end
      end
    end
  end
end
