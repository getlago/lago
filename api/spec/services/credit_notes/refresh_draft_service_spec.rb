# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::RefreshDraftService do
  subject(:refresh_service) { described_class.new(credit_note:, fee:, old_fee_values:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:tax) { create(:tax, organization:, rate: 20) }
  let(:invoice) { create(:invoice, organization:, customer:, fees_amount_cents: 100, coupons_amount_cents: 20) }
  let(:old_fee_values) do
    [
      {
        credit_note_item_id: credit_note_item.id,
        fee_amount_cents: credit_note_item.fee&.amount_cents
      }
    ]
  end

  describe "#call" do
    let(:status) { :draft }
    let(:fee) { create(:fee, invoice:, taxes_rate: 20, amount_cents: 100, precise_coupons_amount_cents: 20) }
    let(:fee_applied_tax) { create(:fee_applied_tax, tax:, fee:, amount_cents: 0) }
    let(:invoice_applied_tax) { create(:invoice_applied_tax, tax:, invoice:) }
    let(:credit_note_item) { create(:credit_note_item, credit_note:, fee: create(:fee, invoice:, taxes_rate: 0)) }
    let(:credit_note) do
      create(
        :credit_note,
        invoice:,
        status:,
        taxes_rate: 0,
        taxes_amount_cents: 0,
        credit_amount_cents: 100,
        balance_amount_cents: 100,
        total_amount_cents: 100
      )
    end

    before do
      fee_applied_tax
      invoice_applied_tax
      credit_note_item
    end

    context "when credit_note is finalized" do
      let(:status) { :finalized }

      it "does not refresh it" do
        expect { refresh_service.call }.not_to change(credit_note, :updated_at)
      end
    end

    it "assigns credit note to the fee" do
      expect { refresh_service.call }.to change { credit_note.reload.items.pluck(:fee_id) }.to([fee.id])
    end

    it "updates vat amounts of the credit note" do
      expect { refresh_service.call }
        .to change { credit_note.reload.taxes_amount_cents }.from(0).to(8)
        .and change(credit_note, :coupons_adjustment_amount_cents).from(0).to(10)
        .and change(credit_note, :credit_amount_cents).from(100).to(48)
        .and change(credit_note, :balance_amount_cents).from(100).to(48)
        .and change(credit_note, :total_amount_cents).from(100).to(48)
    end
  end
end
