# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::AdjustAmountsWithRoundingService do
  subject(:adjust_service) { described_class.new(credit_note:) }

  describe "#call" do
    let(:invoice) do
      create(
        :invoice,
        total_amount_cents: 25000,
        taxes_amount_cents: 5000,
        fees_amount_cents: 20000,
        total_paid_amount_cents: 25000,
        taxes_rate: 25,
        payment_status: :succeeded
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

    let(:credit_note) do
      build(
        :credit_note,
        invoice:,
        taxes_amount_cents: 4833,
        credit_amount_cents: 24167,
        total_amount_cents: 24167
      )
    end

    let(:item) do
      build(
        :credit_note_item,
        amount_cents: 19333,
        precise_amount_cents: 19333
      )
    end

    before do
      fee
      credit_note.items << item
    end

    it "adjust the total and credit amount" do
      result = adjust_service.call

      expect(result).to be_success

      credit_note = result.credit_note
      expect(credit_note).to have_attributes(
        taxes_amount_cents: 4833,
        sub_total_excluding_taxes_amount_cents: 19333,
        credit_amount_cents: 24166,
        total_amount_cents: 24166
      )
    end

    context "when rounding diff is negative" do
      let(:credit_note) do
        build(
          :credit_note,
          invoice:,
          taxes_amount_cents: 2,
          credit_amount_cents: 9,
          total_amount_cents: 9,
          taxes_rate: 20
        )
      end

      let(:item) do
        build(
          :credit_note_item,
          amount_cents: 8,
          precise_amount_cents: 7.6
        )
      end

      it "adds a cent to total" do
        result = adjust_service.call

        expect(result).to be_success

        credit_note = result.credit_note
        expect(credit_note.items.first.amount_cents).to eq(8)
        expect(credit_note).to have_attributes(
          taxes_amount_cents: 2,
          sub_total_excluding_taxes_amount_cents: 8,
          credit_amount_cents: 10,
          total_amount_cents: 10
        )
        expect(credit_note.items.sum(&:amount_cents)).to eq(8)
        expect(credit_note.items.sum(&:precise_amount_cents).round).to eq(8)
      end
    end
  end
end
