# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Analytics::GrossRevenuesController do
  describe "GET /analytics/gross_revenue" do
    subject { get_with_token(organization, "/api/v1/analytics/gross_revenue", params) }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization: organization) }
    let(:params) { {} }

    before do
      allow(Analytics::GrossRevenuesService).to receive(:call).and_call_original
    end

    context "when licence is premium", :premium do
      include_examples "requires API permission", "analytic", "read"

      it "returns the gross revenue" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:gross_revenues]).to eq([])
        expect(Analytics::GrossRevenuesService).to have_received(:call).with(organization, billing_entity_id: nil, currency: nil, months: nil, external_customer_id: nil)
      end

      context "when sending params" do
        let(:params) { {billing_entity_code: billing_entity.code} }

        it "calls the service with the billing_entity_id" do
          subject
          expect(Analytics::GrossRevenuesService).to have_received(:call).with(organization, billing_entity_id: billing_entity.id, currency: nil, months: nil, external_customer_id: nil)
        end
      end
    end

    context "when licence is not premium" do
      it "returns the gross revenue" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:gross_revenues]).to eq([])
      end
    end
  end
end
