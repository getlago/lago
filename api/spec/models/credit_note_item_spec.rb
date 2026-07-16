# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNoteItem do
  subject(:credit_note_item) { create(:credit_note_item) }

  it { is_expected.to belong_to(:credit_note) }
  it { is_expected.to belong_to(:fee) }
  it { is_expected.to belong_to(:organization) }

  describe "#sub_total_excluding_taxes_amount_cents" do
    let(:credit_note_item) { build(:credit_note_item, amount_cents: 100, fee: fee) }
    let(:fee) { build(:fee, amount_cents: 1000, precise_amount_cents: 1000, precise_coupons_amount_cents: 0) }

    context "when there are no coupons applied" do
      it "returns item amount with coupons applied" do
        expect(credit_note_item.sub_total_excluding_taxes_amount_cents).to eq(100)
      end
    end

    context "when there are coupons applied" do
      let(:fee) { build(:fee, amount_cents: 1000, precise_amount_cents: 1000, precise_coupons_amount_cents: 20) }

      it "returns item amount with coupons applied" do
        expect(credit_note_item.sub_total_excluding_taxes_amount_cents).to eq(98)
      end
    end
  end
end
