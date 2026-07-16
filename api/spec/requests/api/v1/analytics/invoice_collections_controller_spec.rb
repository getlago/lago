# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Analytics::InvoiceCollectionsController do # rubocop:disable Rails/FilePath
  describe "GET /analytics/invoice_collection" do
    subject { get_with_token(organization, "/api/v1/analytics/invoice_collection", params) }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization: organization) }
    let(:params) { {} }

    before do
      allow(Analytics::InvoiceCollectionsService).to receive(:call).and_call_original
    end

    context "when licence is premium", :premium do
      include_examples "requires API permission", "analytic", "read"

      it "returns the gross revenue" do
        subject

        expect(response).to have_http_status(:success)

        month = DateTime.parse json[:invoice_collections].first[:month]

        expect(month).to eq(DateTime.current.beginning_of_month)
        expect(json[:invoice_collections].first[:payment_status]).to eq(nil)
        expect(json[:invoice_collections].first[:invoices_count]).to eq(0)
        expect(json[:invoice_collections].first[:amount_cents]).to eq(0.0)
        expect(json[:invoice_collections].first[:currency]).to eq(nil)
        expect(Analytics::InvoiceCollectionsService).to have_received(:call).with(organization, billing_entity_id: nil, currency: nil, months: nil)
      end

      context "when sending params" do
        let(:params) { {billing_entity_code: billing_entity.code} }

        it "calls the service with the billing_entity_id" do
          subject
          expect(Analytics::InvoiceCollectionsService).to have_received(:call).with(organization, billing_entity_id: billing_entity.id, currency: nil, months: nil)
        end
      end
    end

    context "when licence is not premium" do
      it "returns forbidden status" do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
