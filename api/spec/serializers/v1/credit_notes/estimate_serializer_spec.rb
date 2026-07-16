# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CreditNotes::EstimateSerializer do
  subject(:serializer) { described_class.new(estimated_credit_note, root_name:) }

  let(:root_name) { "estimated_credit_note" }

  let(:estimated_credit_note) do
    build(:credit_note).tap do |credit_note|
      credit_note_items.each { |i| credit_note.items << i }
      applied_taxes.each { |t| credit_note.applied_taxes << t }
    end
  end

  let(:credit_note_items) { build_list(:credit_note_item, 2, amount_cents: 100) }
  let(:applied_taxes) { build_list(:credit_note_applied_tax, 2) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result[root_name]["lago_invoice_id"]).to eq(estimated_credit_note.invoice_id)
    expect(result[root_name]["invoice_number"]).to eq(estimated_credit_note.invoice.number)
    expect(result[root_name]["currency"]).to eq(estimated_credit_note.currency)
    expect(result[root_name]["taxes_amount_cents"]).to eq(estimated_credit_note.taxes_amount_cents)
    expect(result[root_name]["sub_total_excluding_taxes_amount_cents"])
      .to eq(estimated_credit_note.sub_total_excluding_taxes_amount_cents)
    expect(result[root_name]["max_creditable_amount_cents"]).to eq(estimated_credit_note.credit_amount_cents)
    expect(result[root_name]["max_refundable_amount_cents"]).to eq(estimated_credit_note.refund_amount_cents)
    expect(result[root_name]["coupons_adjustment_amount_cents"])
      .to eq(estimated_credit_note.coupons_adjustment_amount_cents)
    expect(result[root_name]["taxes_rate"]).to eq(estimated_credit_note.taxes_rate)

    expect(result[root_name]["items"].count).to eq(2)
    expect(result[root_name]["applied_taxes"].count).to eq(2)
  end
end
