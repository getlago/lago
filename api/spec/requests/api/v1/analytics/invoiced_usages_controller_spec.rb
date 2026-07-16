# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Analytics::InvoicedUsagesController do # rubocop:disable Rails/FilePath
  describe "GET /analytics/invoiced_usage" do
    subject { get_with_token(organization, "/api/v1/analytics/invoiced_usage", params) }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization: organization) }
    let(:params) { {} }

    before do
      allow(Analytics::InvoicedUsagesService).to receive(:call).and_call_original
    end

    context "when license is premium", :premium do
      include_examples "requires API permission", "analytic", "read"

      it "returns the invoiced usage" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:invoiced_usages]).to eq([])
        expect(Analytics::InvoicedUsagesService).to have_received(:call).with(organization, billing_entity_id: nil, currency: nil, months: nil)
      end

      context "when sending params" do
        let(:params) { {billing_entity_code: billing_entity.code} }

        it "calls the service with the billing_entity_id" do
          subject
          expect(Analytics::InvoicedUsagesService).to have_received(:call).with(organization, billing_entity_id: billing_entity.id, currency: nil, months: nil)
        end
      end
    end

    context "when license is not premium" do
      it "returns forbidden status" do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
