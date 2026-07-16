# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::FeesController do
  let(:organization) { create(:organization) }

  describe "GET /api/v1/fees/:id" do
    subject { get_with_token(organization, "/api/v1/fees/#{fee_id}") }

    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:fee) { create(:fee, subscription:, invoice: nil) }
    let(:fee_id) { fee.id }

    include_examples "requires API permission", "fee", "read"

    it "returns a fee" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:fee]).to include(
        lago_id: fee.id,
        amount_cents: fee.amount_cents,
        amount_currency: fee.amount_currency,
        taxes_amount_cents: fee.taxes_amount_cents,
        units: fee.units.to_s,
        events_count: fee.events_count,
        applied_taxes: [],
        self_billed: false
      )
      expect(json[:fee][:item]).to include(
        type: fee.fee_type,
        code: fee.item_code,
        name: fee.item_name
      )
    end

    context "when fee is an add-on fee" do
      let(:invoice) { create(:invoice, organization:) }
      let(:fee) { create(:add_on_fee, invoice:) }

      it "returns a fee" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:fee]).to include(
          lago_id: fee.id,
          amount_cents: fee.amount_cents,
          amount_currency: fee.amount_currency,
          taxes_amount_cents: fee.taxes_amount_cents,
          units: fee.units.to_s,
          events_count: fee.events_count,
          applied_taxes: [],
          self_billed: invoice.self_billed
        )
        expect(json[:fee][:item]).to include(
          type: fee.fee_type,
          code: fee.item_code,
          name: fee.item_name
        )
      end
    end

    context "when fee does not exist" do
      let(:fee_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when fee belongs to an other organization" do
      let(:fee) { create(:fee) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PUT /api/v1/fees/:id" do
    subject { put_with_token(organization, "/api/v1/fees/#{fee_id}", fee: update_params) }

    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:update_params) { {payment_status: "succeeded"} }
    let(:fee_id) { fee.id }

    let(:fee) do
      create(:charge_fee, fee_type: "charge", pay_in_advance: true, subscription:, invoice: nil)
    end

    include_examples "requires API permission", "fee", "write"

    it "updates the fee" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:fee]).to include(
        lago_id: fee.reload.id,
        amount_cents: fee.amount_cents,
        amount_currency: fee.amount_currency,
        taxes_amount_cents: fee.taxes_amount_cents,
        units: fee.units.to_s,
        events_count: fee.events_count,
        payment_status: fee.payment_status,
        created_at: fee.created_at&.iso8601,
        succeeded_at: fee.succeeded_at&.iso8601,
        failed_at: fee.failed_at&.iso8601,
        refunded_at: fee.refunded_at&.iso8601,
        amount_details: fee.amount_details,
        applied_taxes: []
      )
      expect(json[:fee][:item]).to include(
        type: fee.fee_type,
        code: fee.item_code,
        name: fee.item_name
      )
    end

    context "when fee does not exist" do
      let(:fee_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/fees/:id" do
    subject { delete_with_token(organization, "/api/v1/fees/#{fee_id}") }

    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let(:update_params) { {payment_status: "succeeded"} }
    let(:fee_id) { fee.id }

    context "when fee exists" do
      let(:fee) do
        create(:charge_fee, fee_type: "charge", pay_in_advance: true, subscription:, invoice:)
      end
      let(:invoice) { nil }

      include_examples "requires API permission", "fee", "write"

      context "when fee does not attached to an invoice" do
        it "deletes the fee" do
          subject
          expect(response).to have_http_status(:ok)
        end
      end

      context "when fee is attached to an invoice" do
        let(:invoice) { create(:invoice, organization:, customer:) }

        it "dont delete the fee" do
          subject
          expect(response).to have_http_status(:method_not_allowed)
        end
      end
    end

    context "when fee does not exist" do
      let(:fee_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/fees" do
    subject { get_with_token(organization, "/api/v1/fees", params) }

    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:) }
    let!(:fee) { create(:fee, subscription:, invoice: nil) }

    context "without params" do
      let(:params) { {} }

      include_examples "requires API permission", "fee", "read"

      it "returns a list of fees" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:fees].count).to eq(1)
        expect(json[:fees].first[:lago_id]).to eq(fee.id)
      end
    end

    context "with an invalid filter" do
      let(:params) { {fee_type: "invalid_filter"} }

      it "returns an error response" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details]).to eq({fee_type: %w[value_is_invalid]})
      end
    end

    context "with unknown params", cache: :memory do
      before do
        create(:fee, subscription:, invoice: nil)
      end

      it "ignores unknown params for caching" do
        # First request populates the cache
        get_with_token(organization, "/api/v1/fees", page: 1, per_page: 1)
        expect(json[:meta][:total_count]).to eq(2)

        # Add a third fee
        create(:fee, subscription:, invoice: nil)

        # Request with unknown param should return cached count (2), not fresh count (3)
        get_with_token(organization, "/api/v1/fees", page: 1, per_page: 1, unknown_param: "value")
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end
end
