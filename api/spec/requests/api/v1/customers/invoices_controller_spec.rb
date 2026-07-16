# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::InvoicesController do
  describe "GET /api/v1/customers/:external_id/invoices" do
    it_behaves_like "an invoice index endpoint" do
      subject { get_with_token(organization, "/api/v1/customers/#{customer.external_id}/invoices", params) }

      context "with invalid customer id" do
        subject { get_with_token(organization, "/api/v1/customers/foo/invoices", {}) }

        it "returns a 404" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end
    end
  end
end
