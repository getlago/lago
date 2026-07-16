# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::ValidateItemService do
  subject(:validator) { described_class.new(result, item:) }

  let(:result) { BaseService::Result.new }
  let(:amount_cents) { 10 }
  let(:credit_amount_cents) { 10 }
  let(:refund_amount_cents) { 0 }
  let(:credit_note) do
    create(
      :credit_note,
      invoice:,
      customer:,
      credit_amount_cents:,
      refund_amount_cents:
    )
  end
  let(:item) do
    build(
      :credit_note_item,
      credit_note:,
      amount_cents:,
      fee:
    )
  end

  let(:invoice) { create(:invoice, total_amount_cents: 120) }
  let(:customer) { invoice.customer }

  let(:fee) { create(:fee, invoice:, amount_cents: 100, taxes_rate: 20) }

  describe ".call" do
    it "validates the item" do
      expect(validator).to be_valid
    end

    context "when fee is missing" do
      let(:fee) { nil }

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("fee")
      end
    end

    context "when amount is negative" do
      let(:amount_cents) { -3 }

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:amount_cents]).to eq(["invalid_value"])
      end
    end

    context "when amount is zero" do
      let(:amount_cents) { 0 }

      it "passes the validation" do
        expect(validator).to be_valid
      end
    end

    context "when amount is higher than fee amount" do
      let(:amount_cents) { fee.amount_cents + 10 }

      before do
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:amount_cents]).to eq(["higher_than_remaining_fee_amount"])
      end
    end

    context "when reaching fee creditable amount" do
      before do
        create(:credit_note_item, fee:, amount_cents: 99)
        create(:fee, invoice:, amount_cents: 100, taxes_rate: 20, taxes_amount_cents: 20)
      end

      it "fails the validation" do
        expect(validator).not_to be_valid

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:amount_cents]).to eq(["higher_than_remaining_fee_amount"])
      end
    end

    context "with offset amounts" do
      it "includes offset amounts in total credit note calculation" do
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 30, refund_amount_cents: 20, offset_amount_cents: 15, status: :finalized)
        item.amount_cents = 20
        expect(validator).to be_valid
      end

      it "validates successfully when within remaining amount after offsets" do
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 30, refund_amount_cents: 20, offset_amount_cents: 40, status: :finalized)
        item.amount_cents = 50
        expect(validator).to be_valid
      end

      it "considers only offset amounts when credit and refund are zero" do
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 25, status: :finalized)
        item.amount_cents = 15
        expect(validator).to be_valid
      end

      it "ignores draft credit notes with offset amounts" do
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 50, refund_amount_cents: 30, offset_amount_cents: 20, status: :draft)
        item.amount_cents = 30
        expect(validator).to be_valid
      end
    end

    context "with credit invoices and wallets" do
      let(:wallet) { create(:wallet, customer:, balance_cents: 1000) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: 1000) }
      let(:fee) { create(:fee, invoice:, fee_type: :credit, invoiceable: wallet_transaction, amount_cents: 1000) }

      before { wallet }

      it "allows offsetting full amount when cancelling prepaid credits with pending payment" do
        invoice.update!(invoice_type: :credit, total_amount_cents: 1000, payment_status: :pending)
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 1000, status: :finalized)
        item.amount_cents = 1000
        expect(validator).to be_valid
      end

      it "allows offsetting full amount when cancelling prepaid credits with failed payment" do
        invoice.update!(invoice_type: :credit, total_amount_cents: 1000, payment_status: :failed)
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 1000, status: :finalized)
        item.amount_cents = 1000
        expect(validator).to be_valid
      end

      it "allows offsetting full amount with succeeded payment" do
        invoice.update!(invoice_type: :credit, total_amount_cents: 500, payment_status: :succeeded)
        fee.update!(amount_cents: 500)
        wallet_transaction.update!(remaining_amount_cents: 500)
        create(:credit_note, invoice:, customer:,
          credit_amount_cents: 0, refund_amount_cents: 0, offset_amount_cents: 500, status: :finalized)
        item.amount_cents = 500
        expect(validator).to be_valid
      end

      it "rejects amount exceeding remaining amount" do
        invoice.update!(invoice_type: :credit, total_amount_cents: 2000, payment_status: :succeeded)
        fee.update!(amount_cents: 2000)
        wallet_transaction.update!(remaining_amount_cents: 800)
        item.amount_cents = 1500

        expect(validator).not_to be_valid
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:amount_cents]).to eq(["higher_than_wallet_balance"])
      end

      context "when wallet is not traceable" do
        let(:wallet) { create(:wallet, customer:, balance_cents: 1000, traceable: false) }
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, remaining_amount_cents: nil) }

        it "allows offsetting up to wallet balance" do
          invoice.update!(invoice_type: :credit, total_amount_cents: 1000, payment_status: :succeeded)
          item.amount_cents = 1000
          expect(validator).to be_valid
        end

        it "rejects amount exceeding wallet balance" do
          invoice.update!(invoice_type: :credit, total_amount_cents: 2000, payment_status: :succeeded)
          fee.update!(amount_cents: 2000)
          item.amount_cents = 1500

          expect(validator).not_to be_valid
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:amount_cents]).to eq(["higher_than_wallet_balance"])
        end
      end
    end
  end
end
