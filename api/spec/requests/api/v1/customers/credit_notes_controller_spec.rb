# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::CreditNotesController do
  describe "GET /api/v1/customers/:external_id/credit_notes" do
    it_behaves_like "a credit note index endpoint" do
      subject { get_with_token(organization, "/api/v1/customers/#{external_id}/credit_notes", params) }

      let(:external_id) { customer.external_id }

      context "with invalid customer id" do
        let(:external_id) { SecureRandom.uuid }

        it "returns an error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end

      context "when customer does not belongs to the organization" do
        let(:customer) { create(:customer) }

        it "returns an error" do
          subject

          expect(response).to have_http_status(:not_found)
          expect(json[:code]).to eq("customer_not_found")
        end
      end
    end
  end
end
