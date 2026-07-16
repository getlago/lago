# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::PaymentsController do
  let(:organization) { create(:organization) }

  describe "POST /api/v1/payments" do
    subject do
      post_with_token(
        organization,
        "/api/v1/payments",
        {payment: params}
      )
    end

    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, organization:, customer:) }
    let(:params) do
      {
        invoice_id: invoice.id,
        amount_cents: 100,
        reference: "ref1"
      }
    end

    let(:payment) { create(:payment, payable: invoice) }

    context "when all parameters are valid" do
      before do
        allow(Payments::ManualCreateService).to receive(:call).and_return(
          BaseService::Result.new.tap { |r| r.payment = payment }
        )
      end

      include_examples "requires API permission", "payment", "write"

      it "delegates to Payments::ManualCreateService" do
        subject

        expect(Payments::ManualCreateService).to have_received(:call).with(organization:, params:)

        expect(response).to have_http_status(:success)
        expect(json[:payment][:lago_id]).to eq(payment.id)
        expect(json[:payment][:invoice_ids].first).to eq(payment.payable.id)
      end
    end

    context "when amount_cents is missing or misspelled", :premium do
      let(:params) do
        {
          invoice_id: invoice.id,
          amount_in_cents: 100,
          reference: "ref1"
        }
      end

      let(:error_details) { {amount_cents: %w[invalid_value]} }

      it "returns a bad request error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)

        expect(json[:code]).to eq("validation_errors")
        expect(json[:error_details]).to eq(error_details)
      end
    end
  end

  describe "GET /api/v1/payments" do
    it_behaves_like "a payment index endpoint" do
      subject { get_with_token(organization, "/api/v1/payments", params) }

      context "with external customer id" do
        let(:params) { {external_customer_id: customer.external_id} }

        let(:invoice_1) { create(:invoice, organization:, customer:) }
        let(:invoice_2) { create(:invoice, organization:, customer: create(:customer, organization:)) }
        let(:payment_1) { create(:payment, organization:, payable: invoice_1) }
        let(:payment_2) { create(:payment, organization:, payable: invoice_2) }

        before do
          payment_1
          payment_2
        end

        it "returns the payments of the customer" do
          subject
          expect(response).to have_http_status(:ok)
          expect(json[:payments].count).to eq(1)
          expect(json[:payments].first[:lago_id]).to eq(payment_1.id)
          expect(json[:payments].first.keys).to eq(%i[
            lago_id
            lago_customer_id
            external_customer_id
            invoice_ids
            invoice_numbers
            lago_payable_id
            payable_type
            amount_cents
            amount_currency
            status
            payment_status
            type
            reference
            payment_provider_code
            payment_provider_type
            external_payment_id
            provider_payment_id
            provider_customer_id
            next_action
            created_at
          ])
        end
      end
    end
  end

  describe "GET /api/v1/payments/:id" do
    subject { get_with_token(organization, "/api/v1/payments/#{id}") }

    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:payment) { create(:payment, payable: invoice) }

    context "when payment exists" do
      let(:id) { payment.id }

      include_examples "requires API permission", "payment", "read"

      it "returns the payment" do
        subject
        expect(response).to have_http_status(:ok)
        expect(json[:payment][:lago_id]).to eq(payment.id)
        expect(json[:payment][:invoice_ids].first).to eq(invoice.id)
        expect(json[:payment].keys).to eq(%i[
          lago_id
          lago_customer_id
          external_customer_id
          invoice_ids
          invoice_numbers
          lago_payable_id
          payable_type
          amount_cents
          amount_currency
          status
          payment_status
          type
          reference
          payment_provider_code
          payment_provider_type
          external_payment_id
          provider_payment_id
          provider_customer_id
          next_action
          created_at
        ])
      end
    end

    context "when payment for a payment request exits" do
      let(:payment_request) { create(:payment_request, customer:, organization:, invoices: [invoice]) }
      let(:payment) { create(:payment, payable: payment_request) }
      let(:id) { payment.id }

      include_examples "requires API permission", "payment", "read"

      it "returns the payment" do
        subject
        expect(response).to have_http_status(:ok)
        expect(json[:payment][:lago_id]).to eq(payment.id)
        expect(json[:payment][:invoice_ids].first).to eq(invoice.id)
      end
    end

    context "when payment does not exist" do
      let(:id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
