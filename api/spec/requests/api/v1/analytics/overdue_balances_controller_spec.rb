# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Analytics::OverdueBalancesController do
  describe "GET /analytics/overdue_balance" do
    subject { get_with_token(organization, "/api/v1/analytics/overdue_balance", params) }

    let(:customer) { create(:customer, organization:) }
    let(:organization) { create(:organization, created_at: DateTime.new(2023, 11, 1)) }
    let(:billing_entity) { create(:billing_entity, organization: organization) }
    let(:params) { {} }

    before do
      allow(Analytics::OverdueBalancesService).to receive(:call).and_call_original
    end

    include_examples "requires API permission", "analytic", "read"

    it "returns the overdue balance" do
      travel_to(DateTime.new(2024, 1, 15)) do
        create(:invoice, customer:, organization:)
        i1 = create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 2.months.ago, total_amount_cents: 1000)
        i2 = create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 5.days.ago, total_amount_cents: 2000)
        i3 = create(:invoice, customer:, organization:, payment_overdue: true, payment_due_date: 1.day.ago, total_amount_cents: 3000)

        subject

        expect(response).to have_http_status(:success)
        expect(json[:overdue_balances]).to match_array(
          [
            {
              month: "2023-11-01T00:00:00.000Z",
              amount_cents: "1000.0",
              currency: "EUR",
              lago_invoice_ids: [i1.id],
              billing_entity_id: organization.default_billing_entity.id
            },
            {
              month: "2024-01-01T00:00:00.000Z",
              amount_cents: "5000.0",
              currency: "EUR",
              lago_invoice_ids: match_array([i2.id, i3.id]),
              billing_entity_id: organization.default_billing_entity.id
            }
          ]
        )
      end
      expect(Analytics::OverdueBalancesService).to have_received(:call).with(organization, billing_entity_id: nil, currency: nil, months: nil, external_customer_id: nil)
    end

    context "when sending params" do
      let(:params) { {billing_entity_code: billing_entity.code} }

      it "calls the service with the billing_entity_id" do
        subject
        expect(Analytics::OverdueBalancesService).to have_received(:call).with(organization, billing_entity_id: billing_entity.id, currency: nil, months: nil, external_customer_id: nil)
      end
    end
  end
end
