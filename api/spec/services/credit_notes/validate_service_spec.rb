# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::ValidateService do
  subject(:validator) { described_class.new(result, item: credit_note) }

  let(:result) { BaseService::Result.new }
  let(:amount_cents) { 10 }
  let(:credit_amount_cents) { 12 }
  let(:refund_amount_cents) { 0 }
  let(:precise_taxes_amount_cents) { 2 }
  let(:precise_coupons_adjustment_amount_cents) { 0 }
  let(:offset_amount_cents) { 0 }

  let(:credit_note) do
    create(
      :credit_note,
      invoice:,
      customer:,
      credit_amount_cents:,
      refund_amount_cents:,
      offset_amount_cents:,
      precise_coupons_adjustment_amount_cents:,
      precise_taxes_amount_cents:
    )
  end

  let(:item) do
    create(
      :credit_note_item,
      credit_note:,
      amount_cents:,
      precise_amount_cents: amount_cents,
      fee:
    )
  end

  let(:invoice) { create(:invoice, total_amount_cents: 120, total_paid_amount_cents:) }
  let(:customer) { invoice.customer }
  let(:total_paid_amount_cents) { 0 }

  let(:fee) do
    create(
      :fee,
      invoice:,
      amount_cents: 100,
      taxes_rate: 20
    )
  end

  before do
    item
    credit_note.reload
  end

  describe ".call" do
    it "validates the credit_note" do
      expect(validator).to be_valid
    end

    context "when invoice is not paid" do
      let(:invoice_status) { "pending" }

      context "when paid amount equals the total amount" do
        let(:refund_amount_cents) { 2 }
        let(:total_paid_amount_cents) { 120 }

        it "fails the validation" do
          expect(validator).not_to be_valid
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:refund_amount_cents]).to eq(["cannot_refund_unpaid_invoice"])
        end
      end

      context "when paid amount does not equal the total amount" do
        let(:refund_amount_cents) { 0 }

        it "validates the credit_note" do
          expect(validator).to be_valid
        end
      end
    end

    context "when amount does not matches items" do
      let(:amount_cents) { 1 }

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["does_not_match_item_amounts"])
      end
    end

    context "when credit amount is higher than invoice amount" do
      let(:credit_amount_cents) { 250 }

      before do
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:credit_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end

      context "when the difference is due to rounding" do
        let(:credit_amount_cents) { 241 }
        let(:amount_cents) { 239 }

        it "passes the validation" do
          expect(validator).to be_valid
        end
      end
    end

    context "when refund amount is positive but invoice is not paid" do
      let(:refund_amount_cents) { 200 }

      before do
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:refund_amount_cents]).to eq(["cannot_refund_unpaid_invoice"])
      end
    end

    context "when refund amount is higher than invoice amount" do
      let(:refund_amount_cents) { 200 }
      let(:total_paid_amount_cents) { 20 }

      before do
        invoice.payment_succeeded!
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:refund_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "when reaching invoice creditable amount" do
      before do
        create(:credit_note, invoice:, total_amount_cents: 99)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:credit_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "when reaching invoice refundable amount" do
      before do
        invoice.payment_succeeded!
        create(:credit_note, invoice:, total_amount_cents: 119, refund_amount_cents: 199, credit_amount_cents: 0)
      end

      let(:credit_amount_cents) { 0 }
      let(:refund_amount_cents) { 10 }
      let(:total_paid_amount_cents) { 5 }

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:refund_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "when total amount is higher than invoice amount" do
      before do
        create(
          :credit_note,
          invoice:,
          credit_amount_cents: 86,
          refund_amount_cents: 33,
          total_amount_cents: 119
        )
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "when invoice is v3 with coupons" do
      let(:invoice) do
        create(
          :invoice,
          currency: "EUR",
          fees_amount_cents: 100,
          coupons_amount_cents: 10,
          taxes_amount_cents: 18,
          total_amount_cents: 108,
          payment_status: :succeeded,
          taxes_rate: 20,
          version_number: 3
        )
      end

      let(:amount_cents) { 20 }
      let(:credit_amount_cents) { 22 }
      let(:refund_amount_cents) { 0 }
      let(:precise_taxes_amount_cents) { 3.6 }
      let(:precise_coupons_adjustment_amount_cents) { 2 }

      it "validates the credit_note" do
        expect(validator).to be_valid
      end

      context "when amount does not matches items" do
        let(:amount_cents) { 1 }

        it "fails the validation" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:base]).to eq(["does_not_match_item_amounts"])
        end
      end

      context "when total amount is zero" do
        let(:credit_amount_cents) { 0 }
        let(:refund_amount_cents) { 0 }
        let(:amount_cents) { 0 }
        let(:precise_taxes_amount_cents) { 0 }
        let(:precise_coupons_adjustment_amount_cents) { 0 }

        it "fails the validation" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:base]).to eq(["total_amount_must_be_positive"])
        end
      end
    end

    context "with rounding adjustment" do
      let(:invoice) do
        create(
          :invoice,
          total_amount_cents: 25000,
          taxes_amount_cents: 5000,
          fees_amount_cents: 20000,
          total_paid_amount_cents: 25000,
          taxes_rate: 25
        )
      end

      let(:fee) do
        create(
          :fee,
          invoice:,
          amount_cents: 20000,
          taxes_rate: 25
        )
      end

      let(:amount_cents) { 19333 }
      let(:credit_amount_cents) { 24166 }
      let(:precise_taxes_amount_cents) { 4833.3333 }

      it "passes the validation" do
        expect(validator).to be_valid
      end
    end

    context "when the difference is due to rounding" do
      let(:credit_amount_cents) { 241 }
      let(:amount_cents) { 239 }

      before do
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "passes the validation" do
        expect(validator).to be_valid
      end
    end

    context "when credit amount exceeds remaining after offset" do
      let(:credit_amount_cents) { 100 }
      let(:precise_taxes_amount_cents) { 0 }

      before do
        # With offset of 22, only 98 is creditable (120 - 22)
        create(
          :credit_note,
          invoice:,
          customer:,
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          offset_amount_cents: 22, # we have an offset of 1 cent because of rounding issues(so 21 would pass)
          status: :finalized
        )
      end

      it "fails validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:credit_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "when offset_amount_cents exceeds invoice due amount" do
      let(:credit_amount_cents) { 0 }
      let(:offset_amount_cents) { 24 }
      let(:invoice) {
        create(:invoice,
          total_amount_cents: 12,
          total_paid_amount_cents: 12)
      }

      it "fails validation" do
        expect(validator).not_to be_valid
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:offset_amount_cents]).to eq(["higher_than_remaining_invoice_amount"])
      end
    end

    context "with combined credit, refund, and offset amounts" do
      let(:amount_cents) { 50 }
      let(:offset_amount_cents) { 20 }
      let(:credit_amount_cents) { 10 }
      let(:refund_amount_cents) { 20 }
      let(:total_paid_amount_cents) { 50 }
      let(:precise_taxes_amount_cents) { 0 }

      before do
        invoice.payment_succeeded!
      end

      it "includes all three in total_amount_cents calculation" do
        expect(validator).to be_valid
      end
    end

    context "when total with offset is zero" do
      let(:amount_cents) { 0 }
      let(:offset_amount_cents) { 0 }
      let(:credit_amount_cents) { 0 }
      let(:refund_amount_cents) { 0 }
      let(:precise_taxes_amount_cents) { 0 }

      it "fails validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["total_amount_must_be_positive"])
      end
    end

    context "when invoice is type credit and payment status is succeeded" do
      let(:invoice) {
        create(:invoice,
          :credit,
          total_amount_cents: 12,
          total_paid_amount_cents: 12,
          payment_status: :succeeded)
      }

      context "when credit_amount_cents is set" do
        let(:credit_amount_cents) { 12 }

        it "fails validation for credit invoice with credit_amount" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:credit_amount_cents]).to eq(["cannot_credit_invoice"])
        end
      end

      context "when offset_amount_cents is set not covering the full invoice" do
        let(:credit_amount_cents) { 0 }
        let(:offset_amount_cents) { 7 }

        it "fails validation for credit invoice with offset_amount_cents when is paid" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:offset_amount_cents]).to eq(["cannot_apply_to_paid_invoice"])
        end
      end

      context "when offset_amount_cents is set fully covering the invoice" do
        let(:credit_amount_cents) { 0 }
        let(:offset_amount_cents) { 12 }

        it "fails validation for credit invoice with offset_amount_cents when is paid" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:offset_amount_cents]).to eq(["cannot_apply_to_paid_invoice"])
        end
      end
    end

    context "when invoice is type credit but not paid" do
      let(:invoice) {
        create(:invoice,
          :credit,
          total_amount_cents: 12,
          total_paid_amount_cents: 0,
          payment_status: :pending)
      }

      context "when offset_amount_cents is set not covering the full invoice" do
        let(:credit_amount_cents) { 0 }
        let(:offset_amount_cents) { 7 }

        it "fails validation for credit invoice" do
          expect(validator).not_to be_valid

          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:offset_amount_cents]).to eq(["not_equal_to_total_amount"])
        end
      end

      context "when offset_amount_cents is set fully covering the invoice" do
        let(:credit_amount_cents) { 0 }
        let(:offset_amount_cents) { 12 }

        it "passes the validation" do
          expect(validator).to be_valid
        end
      end
    end
  end
end
