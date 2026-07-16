# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::CreditNotesController do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, :with_tax_integration, organization:) }
  let(:credit_note) { create(:credit_note, invoice:, customer:) }
  let(:total_paid_amount_cents) { 120 }
  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      payment_status: "succeeded",
      currency: "EUR",
      fees_amount_cents: 100,
      taxes_amount_cents: 120,
      total_amount_cents: 120,
      total_paid_amount_cents:
    )
  end

  describe "GET /api/v1/credit_notes/:id" do
    subject { get_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}") }

    let(:credit_note_id) { credit_note.id }
    let!(:credit_note_items) { create_list(:credit_note_item, 2, credit_note:) }

    include_examples "requires API permission", "credit_note", "read"

    it "returns a credit note" do
      subject

      expect(response).to have_http_status(:success)

      expect(json[:credit_note]).to include(
        lago_id: credit_note.id,
        sequential_id: credit_note.sequential_id,
        number: credit_note.number,
        lago_invoice_id: invoice.id,
        invoice_number: invoice.number,
        credit_status: credit_note.credit_status,
        reason: credit_note.reason,
        currency: credit_note.currency,
        total_amount_cents: credit_note.total_amount_cents,
        credit_amount_cents: credit_note.credit_amount_cents,
        balance_amount_cents: credit_note.balance_amount_cents,
        created_at: credit_note.created_at.iso8601,
        updated_at: credit_note.updated_at.iso8601,
        applied_taxes: [],
        self_billed: invoice.self_billed
      )

      expect(json[:credit_note][:items].count).to eq(2)

      item = credit_note_items.first
      expect(json[:credit_note][:items][0]).to include(
        lago_id: item.id,
        amount_cents: item.amount_cents,
        amount_currency: item.amount_currency
      )

      expect(json[:credit_note][:items][0][:fee][:item]).to include(
        type: item.fee.fee_type,
        code: item.fee.item_code,
        name: item.fee.item_name
      )

      expect(json[:credit_note][:customer][:lago_id]).to eq(customer.id)
      expect(json[:credit_note][:customer][:integration_customers].count).to eq(1)
      expect(json[:credit_note][:customer][:integration_customers].first[:lago_id]).to eq(customer.anrok_customer.id)
    end

    context "when credit note does not exists" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note is draft" do
      let(:credit_note) { create(:credit_note, :draft) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note belongs to another organization" do
      let(:wrong_credit_note) { create(:credit_note) }
      let(:credit_note_id) { wrong_credit_note.id }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with metadata" do
      before do
        create(
          :item_metadata,
          owner: credit_note,
          organization:,
          value: {"foo" => "bar", "bar" => "", "baz" => nil, "" => "qux"}
        )
      end

      it "returns metadata" do
        subject
        expect(json[:credit_note][:metadata]).to eq(foo: "bar", bar: "", baz: nil, "": "qux")
      end
    end

    context "without metadata" do
      it "returns nil" do
        subject
        expect(json[:credit_note][:metadata]).to be_nil
      end
    end

    context "with empty metadata" do
      before do
        create(:item_metadata, owner: credit_note, organization:, value: {})
      end

      it "returns empty hash" do
        subject
        expect(json[:credit_note][:metadata]).to eq({})
      end
    end
  end

  describe "PUT /api/v1/credit_notes/:id" do
    subject do
      put_with_token(
        organization,
        "/api/v1/credit_notes/#{credit_note_id}",
        credit_note: update_params
      )
    end

    let(:credit_note_id) { credit_note.id }
    let(:update_params) { {refund_status: "succeeded"} }

    include_examples "requires API permission", "credit_note", "write"

    context "when credit not exists" do
      it "updates the credit note" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:lago_id]).to eq(credit_note.id)
        expect(json[:credit_note][:refund_status]).to eq("succeeded")
        expect(json[:credit_note][:customer][:lago_id]).to eq(customer.id)
      end
    end

    context "when credit note does not exist" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when provided refund status is invalid" do
      let(:update_params) { {refund_status: "invalid_status"} }

      it "returns an unprocessable entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with metadata" do
      before do
        create(:item_metadata, owner: credit_note, organization:, value: {"existing" => "value"})
      end

      context "when adding new keys" do
        let(:update_params) { {metadata: {new: "data"}} }

        it "merges metadata (not replaces)" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:credit_note][:metadata]).to eq(existing: "value", new: "data")
        end
      end

      context "when updating existing keys" do
        let(:update_params) { {metadata: {existing: "updated"}} }

        it "updates the key value" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:credit_note][:metadata]).to eq(existing: "updated")
        end
      end

      context "with empty metadata" do
        let(:update_params) { {metadata: {}} }

        it "keeps existing metadata unchanged" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:credit_note][:metadata]).to eq(existing: "value")
        end
      end
    end

    context "without existing metadata" do
      let(:update_params) { {metadata: {foo: "bar", baz: "qux"}} }

      it "creates new metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:metadata]).to eq(foo: "bar", baz: "qux")
      end
    end
  end

  describe "POST /api/v1/credit_notes/:id/download_pdf" do
    subject do
      post_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/download_pdf")
    end

    let(:credit_note_id) { credit_note.id }

    include_examples "requires API permission", "credit_note", "write"

    it "enqueues a job to generate the PDF" do
      subject

      expect(response).to have_http_status(:success)
      expect(CreditNotes::GeneratePdfJob).to have_been_enqueued
    end

    context "when a file is attached to the credit note" do
      let(:credit_note) { create(:credit_note, :with_file, invoice:, customer:) }

      it "returns the credit note object" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note]).to be_present
      end
    end

    context "when credit note does not exist" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note is draft" do
      let(:credit_note) { create(:credit_note, :draft) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note belongs to another organization" do
      let(:wrong_credit_note) { create(:credit_note) }
      let(:credit_note_id) { wrong_credit_note.id }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/credit_notes/:id/download_xml" do
    subject do
      post_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/download_xml")
    end

    let(:credit_note_id) { credit_note.id }

    include_examples "requires API permission", "credit_note", "write"

    it "enqueues a job to generate the PDF" do
      subject

      expect(response).to have_http_status(:success)
      expect(CreditNotes::GenerateXmlJob).to have_been_enqueued
    end

    context "when a file is attached to the credit note" do
      let(:credit_note) { create(:credit_note, :with_file, invoice:, customer:) }

      it "returns the credit note object" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note]).to be_present
      end
    end

    context "when credit note does not exist" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note is draft" do
      let(:credit_note) { create(:credit_note, :draft) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note belongs to another organization" do
      let(:wrong_credit_note) { create(:credit_note) }
      let(:credit_note_id) { wrong_credit_note.id }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/credit_notes" do
    it_behaves_like "a credit note index endpoint" do
      subject { get_with_token(organization, "/api/v1/credit_notes", params) }

      context "with external_customer_id filter" do
        let(:params) { {external_customer_id: customer.external_id} }
        let!(:credit_note) { create(:credit_note, customer:) }

        before do
          another_customer = create(:customer, organization:)
          create(:credit_note, customer: another_customer)
        end

        it "returns credit notes of the customer" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:credit_notes].pluck(:lago_id)).to contain_exactly credit_note.id
        end

        it "returns nested customer data" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:credit_notes].first[:customer][:lago_id]).to eq(customer.id)

          expect(json[:credit_notes].first[:customer][:billing_configuration].keys).to eq(%i[
            invoice_grace_period
            payment_provider
            payment_provider_code
            document_locale
            subscription_invoice_issuing_date_anchor
            subscription_invoice_issuing_date_adjustment
          ])
        end
      end
    end
  end

  describe "POST /api/v1/credit_notes", :premium do
    subject do
      post_with_token(organization, "/api/v1/credit_notes", {credit_note: create_params})
    end

    let(:fee1) { create(:fee, invoice:) }
    let(:fee2) { create(:charge_fee, invoice:) }
    let(:invoice_id) { invoice.id }

    let(:create_params) do
      {
        invoice_id:,
        reason: "duplicated_charge",
        description: "Duplicated charge",
        credit_amount_cents: 10,
        refund_amount_cents: 5,
        items: [
          {
            fee_id: fee1.id,
            amount_cents: 10
          },
          {
            fee_id: fee2.id,
            amount_cents: 5
          }
        ]
      }
    end

    include_examples "requires API permission", "credit_note", "write"

    it "creates a credit note" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_note]).to include(
        credit_status: "available",
        refund_status: "pending",
        reason: "duplicated_charge",
        description: "Duplicated charge",
        currency: "EUR",
        total_amount_cents: 15,
        credit_amount_cents: 10,
        balance_amount_cents: 10,
        refund_amount_cents: 5,
        applied_taxes: []
      )

      expect(json[:credit_note][:customer][:lago_id]).to eq(customer.id)
      expect(json[:credit_note][:items][0][:lago_id]).to be_present
      expect(json[:credit_note][:items][0][:amount_cents]).to eq(10)
      expect(json[:credit_note][:items][0][:amount_currency]).to eq("EUR")
      expect(json[:credit_note][:items][0][:fee][:lago_id]).to eq(fee1.id)

      expect(json[:credit_note][:items][1][:lago_id]).to be_present
      expect(json[:credit_note][:items][1][:amount_cents]).to eq(5)
      expect(json[:credit_note][:items][1][:amount_currency]).to eq("EUR")
      expect(json[:credit_note][:items][1][:fee][:lago_id]).to eq(fee2.id)
    end

    context "when invoice is not found" do
      let(:invoice_id) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when total amount is zero" do
      let(:create_params) do
        {
          invoice_id:,
          reason: "duplicated_charge",
          description: "Duplicated charge",
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          items: [
            {
              fee_id: fee1.id,
              amount_cents: 0
            },
            {
              fee_id: fee2.id,
              amount_cents: 0
            }
          ]
        }
      end

      it "returns validation error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details][:base]).to eq(["total_amount_must_be_positive"])
      end
    end

    context "with metadata" do
      let(:create_params) do
        {
          invoice_id:,
          reason: "duplicated_charge",
          description: "Duplicated charge",
          credit_amount_cents: 10,
          refund_amount_cents: 5,
          items: [{fee_id: fee1.id, amount_cents: 10}, {fee_id: fee2.id, amount_cents: 5}],
          metadata: {foo: "bar", baz: "qux"}
        }
      end

      it "creates credit note with metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:metadata]).to eq(foo: "bar", baz: "qux")
      end
    end

    context "with empty metadata" do
      let(:create_params) do
        {
          invoice_id:,
          reason: "duplicated_charge",
          description: "Duplicated charge",
          credit_amount_cents: 10,
          refund_amount_cents: 5,
          items: [{fee_id: fee1.id, amount_cents: 10}, {fee_id: fee2.id, amount_cents: 5}],
          metadata: {}
        }
      end

      it "creates credit note with empty metadata" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:metadata]).to eq({})
      end
    end

    context "with offset_amount_cents" do
      let(:total_paid_amount_cents) { 100 } # Leave 20 cents unpaid for offset

      let(:create_params) do
        {
          invoice_id:,
          reason: "duplicated_charge",
          description: "Duplicated charge",
          credit_amount_cents: 10,
          refund_amount_cents: 5,
          offset_amount_cents: 8,
          items: [
            {fee_id: fee1.id, amount_cents: 15},
            {fee_id: fee2.id, amount_cents: 8}
          ]
        }
      end

      it "creates credit note with offset amount" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:offset_amount_cents]).to eq(8)
        expect(json[:credit_note][:credit_amount_cents]).to eq(10)
        expect(json[:credit_note][:refund_amount_cents]).to eq(5)
        expect(json[:credit_note][:total_amount_cents]).to eq(23) # 10 + 5 + 8
      end

      it "creates an invoice settlement for the offset amount" do
        expect { subject }.to change(InvoiceSettlement, :count).by(1)

        invoice_settlement = InvoiceSettlement.last
        expect(invoice_settlement.target_invoice_id).to eq(invoice.id)
        expect(invoice_settlement.amount_cents).to eq(8)
        expect(invoice_settlement.settlement_type).to eq("credit_note")
      end
    end

    context "with only offset_amount_cents (no credit or refund)" do
      let(:total_paid_amount_cents) { 100 } # Leave 20 cents unpaid for offset

      let(:create_params) do
        {
          invoice_id:,
          reason: "duplicated_charge",
          description: "Duplicated charge",
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          offset_amount_cents: 15,
          items: [{fee_id: fee1.id, amount_cents: 15}]
        }
      end

      it "creates credit note with only offset amount" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:credit_note][:offset_amount_cents]).to eq(15)
        expect(json[:credit_note][:credit_amount_cents]).to eq(0)
        expect(json[:credit_note][:refund_amount_cents]).to eq(0)
        expect(json[:credit_note][:total_amount_cents]).to eq(15)
      end
    end

    context "with credit invoices" do
      let(:wallet) { create(:wallet, customer:, balance_cents: 100) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, invoice: credit_invoice, organization:) }
      let(:credit_fee) { create(:credit_fee, invoice: credit_invoice, wallet_transaction:, organization:, amount_cents: 100, taxes_amount_cents: 0) }

      context "when payment is pending" do
        let(:credit_invoice) do
          create(:invoice, organization:, customer:, invoice_type: :credit, payment_status: "pending", currency: "EUR", total_amount_cents: 100, fees_amount_cents: 100)
        end

        context "with offset_amount_cents" do
          let(:create_params) do
            {
              invoice_id: credit_invoice.id,
              reason: "other",
              offset_amount_cents: 100,
              items: [{fee_id: credit_fee.id, amount_cents: 100}]
            }
          end

          it "creates credit note successfully" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:credit_note][:offset_amount_cents]).to eq(100)
          end
        end

        context "with credit_amount_cents" do
          let(:create_params) do
            {
              invoice_id: credit_invoice.id,
              reason: "other",
              credit_amount_cents: 50,
              items: [{fee_id: credit_fee.id, amount_cents: 50}]
            }
          end

          it "returns an error" do
            subject

            expect(response).to have_http_status(:method_not_allowed)
          end
        end
      end

      context "when payment failed" do
        let(:credit_invoice) do
          create(:invoice, organization:, customer:,
            invoice_type: :credit,
            payment_status: "failed",
            currency: "EUR",
            total_amount_cents: 100,
            fees_amount_cents: 100)
        end

        context "with offset_amount_cents" do
          let(:create_params) do
            {
              invoice_id: credit_invoice.id,
              reason: "other",
              offset_amount_cents: 100,
              items: [{fee_id: credit_fee.id, amount_cents: 100}]
            }
          end

          it "creates credit note successfully" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:credit_note][:offset_amount_cents]).to eq(100)
          end
        end

        context "with credit_amount_cents" do
          let(:create_params) do
            {
              invoice_id: credit_invoice.id,
              reason: "other",
              credit_amount_cents: 50,
              items: [{fee_id: credit_fee.id, amount_cents: 50}]
            }
          end

          it "returns an error" do
            subject

            expect(response).to have_http_status(:method_not_allowed)
          end
        end
      end
    end
  end

  describe "PUT /api/v1/credit_notes/:id/void" do
    subject { put_with_token(organization, "/api/v1/credit_notes/#{credit_note_id}/void") }

    let(:credit_note_id) { credit_note.id }

    include_examples "requires API permission", "credit_note", "write"

    it "voids the credit note" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:credit_note][:lago_id]).to eq(credit_note.id)
      expect(json[:credit_note][:credit_status]).to eq("voided")
      expect(json[:credit_note][:balance_amount_cents]).to eq(0)
      expect(json[:credit_note][:customer][:lago_id]).to eq(customer.id)
    end

    context "when credit note does not exist" do
      let(:credit_note_id) { SecureRandom.uuid }

      it "returns a not found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when credit note is not voidable" do
      before { credit_note.update!(credit_amount_cents: 0, credit_status: :voided) }

      it "returns an unprocessable entity error" do
        subject
        expect(response).to have_http_status(:method_not_allowed)
      end
    end
  end

  describe "POST /api/v1/credit_notes/estimate", :premium do
    subject do
      post_with_token(
        organization,
        "/api/v1/credit_notes/estimate",
        {credit_note: estimate_params}
      )
    end

    let(:fees) { create_list(:fee, 2, invoice:, amount_cents: 100) }
    let(:invoice_id) { invoice.id }
    let(:total_paid_amount_cents) { 0 }

    let(:estimate_params) do
      {
        invoice_id:,
        items: fees.map { |f| {fee_id: f.id, amount_cents: 50} }
      }
    end

    include_examples "requires API permission", "credit_note", "write"

    it "returns the computed amounts for credit note creation" do
      subject

      expect(response).to have_http_status(:success)

      estimated_credit_note = json[:estimated_credit_note]
      expect(estimated_credit_note[:lago_invoice_id]).to eq(invoice.id)
      expect(estimated_credit_note[:invoice_number]).to eq(invoice.number)
      expect(estimated_credit_note[:currency]).to eq("EUR")
      expect(estimated_credit_note[:taxes_amount_cents]).to eq(0)
      expect(estimated_credit_note[:sub_total_excluding_taxes_amount_cents]).to eq(100)
      expect(estimated_credit_note[:max_creditable_amount_cents]).to eq(100)
      expect(estimated_credit_note[:max_refundable_amount_cents]).to eq(0)
      expect(estimated_credit_note[:coupons_adjustment_amount_cents]).to eq(0)
      expect(estimated_credit_note[:items].first[:amount_cents]).to eq(50)
      expect(estimated_credit_note[:applied_taxes]).to be_blank
    end

    context "with invalid invoice" do
      let(:invoice) { create(:invoice) }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
