# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentReceiptsQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:returned_ids) { result.payment_receipts.pluck(:id) }
  let(:pagination) { nil }
  let(:filters) { nil }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invoice) { create(:invoice, organization:) }
  let(:invoice2) { create(:invoice, organization:) }
  let(:payment_request) { create(:payment_request, organization:) }
  let(:payment_one) { create(:payment, payable: invoice) }
  let(:payment_two) { create(:payment, payable: invoice2) }
  let(:payment_three) { create(:payment, payable: payment_request) }

  let!(:payment_receipt_one) { create(:payment_receipt, payment: payment_one, organization:) }
  let!(:payment_receipt_two) { create(:payment_receipt, payment: payment_two, organization:) }
  let!(:payment_receipt_three) { create(:payment_receipt, payment: payment_three, organization:) }

  before do
    create(:payment_receipt)
  end

  it "returns all payment_receipts for the organization" do
    expect(result).to be_success
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(payment_receipt_one.id)
    expect(returned_ids).to include(payment_receipt_two.id)
    expect(returned_ids).to include(payment_receipt_three.id)
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.payment_receipts.count).to eq(1)
      expect(result.payment_receipts.current_page).to eq(2)
      expect(result.payment_receipts.prev_page).to eq(1)
      expect(result.payment_receipts.next_page).to be_nil
      expect(result.payment_receipts.total_pages).to eq(2)
      expect(result.payment_receipts.total_count).to eq(3)
    end
  end

  context "when filtering by invoice_id" do
    let(:filters) { {invoice_id: invoice.id} }

    it "returns only payment_receipts for the specified invoice" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to include(payment_receipt_one.id)
    end
  end

  context "when filtering by invoice_id of a payment request" do
    let(:filters) { {invoice_id: invoice_pr.id} }
    let(:invoice_pr) { create(:invoice, organization:) }

    before do
      create(:payment_request_applied_invoice, invoice: invoice_pr, payment_request:)
    end

    it "returns only payment_receipts for the specified invoice" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(1)
      expect(returned_ids).to include(payment_receipt_three.id)
    end
  end

  context "when filtering with an invalid invoice_id" do
    let(:filters) { {invoice_id: "invalid-uuid"} }

    it "returns a validation error" do
      expect(result).not_to be_success
      expect(result.error.messages[:invoice_id]).to include("is in invalid format")
    end
  end

  context "when no payment_receipts exist" do
    before do
      PaymentReceipt.delete_all
    end

    it "returns an empty result set" do
      expect(result).to be_success
      expect(returned_ids).to be_empty
    end
  end
end
