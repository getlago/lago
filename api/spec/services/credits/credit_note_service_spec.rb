# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credits::CreditNoteService do
  subject(:credit_service) { described_class.new(invoice:, context:) }

  let(:invoice) do
    create(
      :invoice,
      customer:,
      currency: "EUR",
      total_amount_cents: amount_cents
    )
  end

  let(:amount_cents) { 100 }
  let(:subscription) { create(:subscription, customer:) }
  let(:subscription_fees) { [fee1, fee2] }
  let(:fee1) { create(:fee, invoice:, subscription:, amount_cents: 60, taxes_amount_cents: 0) }
  let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, taxes_amount_cents: 0) }
  let(:customer) { create(:customer) }
  let(:context) { nil }

  let(:credit_note1) do
    create(
      :credit_note,
      total_amount_cents: 20,
      balance_amount_cents: 20,
      credit_amount_cents: 20,
      customer:
    )
  end

  let(:credit_note2) do
    create(
      :credit_note,
      total_amount_cents: 50,
      balance_amount_cents: 50,
      credit_amount_cents: 50,
      customer:
    )
  end

  before do
    credit_note1
    credit_note2
    subscription_fees
  end

  describe "concurrent invoice processing", transaction: false do
    let(:amount_cents) { 3100 }
    let(:credit_cents) { 1000 }
    let(:customer1) { create(:customer) }

    let(:invoice1) { create(:invoice, customer: customer1, total_amount_cents: amount_cents) }
    let(:invoice2) { create(:invoice, customer: customer1, total_amount_cents: amount_cents) }
    let(:invoice3) { create(:invoice, customer: customer1, total_amount_cents: amount_cents) }

    let(:credit_note1) { create(:credit_note, customer: customer1, balance_amount_cents: credit_cents) }
    let(:credit_note2) { create(:credit_note, customer: customer1, balance_amount_cents: credit_cents) }
    let(:credit_note3) { create(:credit_note, customer: customer1, balance_amount_cents: credit_cents) }

    before do
      credit_note1
      credit_note2
      credit_note3
    end

    it "applies credit notes correctly under concurrent access" do
      threads = [invoice1, invoice2, invoice3].map do |invoice|
        Thread.new do
          described_class.call(invoice:)
        end
      end

      threads.each(&:join)

      expect(credit_note1.reload.balance_amount_cents).to eq(0)
      expect(credit_note2.reload.balance_amount_cents).to eq(0)
      expect(credit_note3.reload.balance_amount_cents).to eq(0)
      expect(
        invoice1.credits.sum(:amount_cents) + invoice2.credits.sum(:amount_cents) + invoice3.credits.sum(:amount_cents)
      ).to eq(credit_cents * 3)
    end
  end

  describe ".call" do
    it "creates a list of credits" do
      result = credit_service.call

      expect(result).to be_success
      expect(result.credits.count).to eq(2)

      credit1 = result.credits.first
      expect(credit1.invoice).to eq(invoice)
      expect(credit1.credit_note).to eq(credit_note1)
      expect(credit1.amount_cents).to eq(20)
      expect(credit1.amount_currency).to eq("EUR")
      expect(credit1.before_taxes).to eq(false)
      expect(credit_note1.reload.balance_amount_cents).to be_zero
      expect(credit_note1).to be_consumed

      credit2 = result.credits.last
      expect(credit2.invoice).to eq(invoice)
      expect(credit2.credit_note).to eq(credit_note2)
      expect(credit2.amount_cents).to eq(50)
      expect(credit2.amount_currency).to eq("EUR")
      expect(credit2.before_taxes).to eq(false)
      expect(credit_note2.reload.balance_amount_cents).to be_zero
      expect(credit_note1).to be_consumed

      expect(invoice.credit_notes_amount_cents).to eq(70)

      expect(fee1.reload.precise_credit_notes_amount_cents).to eq(42)
      expect(fee2.reload.precise_credit_notes_amount_cents).to eq(28)
    end

    it "creates credits in the database" do
      expect { credit_service.call }.to change(Credit, :count).by(2)
    end

    context "when preview mode" do
      let(:context) { :preview }

      it "does not create credits in the database" do
        expect { credit_service.call }.not_to change(Credit, :count)
      end
    end

    context "when invoice amount is 0" do
      let(:amount_cents) { 0 }

      it "does not create a credit" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.credits.count).to eq(0)
      end
    end

    context "when credit notes have a different currency than the invoice" do
      let(:credit_note_usd) do
        create(
          :credit_note,
          total_amount_cents: 30,
          total_amount_currency: "USD",
          balance_amount_cents: 30,
          balance_amount_currency: "USD",
          credit_amount_cents: 30,
          credit_amount_currency: "USD",
          customer:
        )
      end

      before { credit_note_usd }

      it "only applies credit notes matching the invoice currency" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.credits.count).to eq(2)
        expect(result.credits.map(&:credit_note)).to match_array([credit_note1, credit_note2])
        expect(credit_note_usd.reload.balance_amount_cents).to eq(30)
      end
    end

    context "when credit amount is higher than invoice amount" do
      let(:amount_cents) { 10 }

      it "creates a credit with partial credit note amount" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.credits.count).to eq(1)

        credit = result.credits.first
        expect(credit.invoice).to eq(invoice)
        expect(credit.credit_note).to eq(credit_note1)
        expect(credit.amount_cents).to eq(10)
        expect(credit.amount_currency).to eq("EUR")
        expect(credit_note1.reload.balance_amount_cents).to eq(10)
        expect(credit_note1).to be_available
      end
    end
  end
end
