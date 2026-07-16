# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::SubscriptionsController do
  describe "GET /api/v1/customers/:external_id/subscriptions" do
    subject { get_with_token(organization, "/api/v1/customers/#{external_id}/subscriptions", params) }

    it_behaves_like "a subscription index endpoint" do
      let(:external_id) { customer.external_id }
      let(:subscription_2) { create(:subscription, customer: customer_2, organization:, plan:) }
      let(:customer_2) { create(:customer, organization:) }

      before do
        subscription_2
      end

      context "with unknown customer id" do
        let(:external_id) { "unknown_customer_id" }

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
