# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::PaymentReceiptsController do
  let(:organization) { create(:organization) }

  describe "GET /api/v1/payment_receipts" do
    subject { get_with_token(organization, "/api/v1/payment_receipts", params) }

    let(:params) { {} }

    include_examples "requires API permission", "invoice", "read"

    it "returns organization's payments" do
      invoice = create(:invoice, organization:)
      invoice2 = create(:invoice, organization:)
      payment_request = create(:payment_request, organization:)
      first_payment = create(:payment, payable: invoice)
      second_payment = create(:payment, payable: invoice2)
      third_payment = create(:payment, payable: payment_request)

      first_payment_receipt = create(:payment_receipt, payment: first_payment, organization:)
      second_payment_receipt = create(:payment_receipt, payment: second_payment, organization:)
      third_payment_receipt = create(:payment_receipt, payment: third_payment, organization:)
      create(:payment_receipt)

      subject

      expect(response).to have_http_status(:success)
      expect(json[:payment_receipts].count).to eq(3)
      expect(json[:payment_receipts].map { |r| r[:lago_id] }).to contain_exactly(
        first_payment_receipt.id,
        second_payment_receipt.id,
        third_payment_receipt.id
      )
    end

    context "with a not found invoice" do
      let(:params) { {invoice_id: SecureRandom.uuid} }

      before do
        invoice = create(:invoice, organization:)
        payment = create(:payment, payable: invoice)
        create(:payment_receipt, payment:)
      end

      it "returns an empty result" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:payment_receipts]).to be_empty
      end
    end

    context "with invoice" do
      let(:invoice) { create(:invoice, organization:) }
      let(:invoice2) { create(:invoice, organization:) }
      let(:params) { {invoice_id: invoice.id} }
      let(:first_payment) { create(:payment, payable: invoice) }
      let(:first_payment_receipt) { create(:payment_receipt, payment: first_payment, organization:) }

      let(:second_payment) { create(:payment, payable: invoice2) }

      before do
        first_payment_receipt
        create(:payment_receipt, payment: second_payment)
      end

      it "returns invoices's payment receipts" do
        subject
        expect(response).to have_http_status(:success)
        expect(json[:payment_receipts].map { |r| r[:lago_id] }).to contain_exactly(first_payment_receipt.id)
        expect(json[:payment_receipts].first[:payment][:invoice_ids].first).to eq(invoice.id)
      end
    end
  end

  describe "GET /api/v1/payment_receipts/:id" do
    subject { get_with_token(organization, "/api/v1/payment_receipts/#{id}") }

    let(:customer) { create(:customer, organization:) }
    let(:invoice) { create(:invoice, customer:, organization:) }
    let(:payment) { create(:payment, payable: invoice) }
    let(:payment_receipt) { create(:payment_receipt, payment:, organization:) }

    context "when payment receipt exists" do
      let(:id) { payment_receipt.id }

      include_examples "requires API permission", "invoice", "read"

      it "returns the payment receipt" do
        subject
        expect(response).to have_http_status(:ok)
        expect(json[:payment_receipt][:lago_id]).to eq(payment_receipt.id)
        expect(json[:payment_receipt][:payment][:invoice_ids].first).to eq(invoice.id)
      end
    end

    context "when payment for a payment request exists" do
      let(:payment_request) { create(:payment_request, customer:, organization:, invoices: [invoice]) }
      let(:payment) { create(:payment, payable: payment_request) }
      let(:payment_receipt) { create(:payment_receipt, payment:, organization:) }
      let(:id) { payment_receipt.id }

      include_examples "requires API permission", "invoice", "read"

      it "returns the payment receipt" do
        subject
        expect(response).to have_http_status(:ok)
        expect(json[:payment_receipt][:lago_id]).to eq(payment_receipt.id)
        expect(json[:payment_receipt][:payment][:invoice_ids].first).to eq(invoice.id)
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
