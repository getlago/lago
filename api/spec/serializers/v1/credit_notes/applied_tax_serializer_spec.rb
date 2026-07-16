# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CreditNotes::AppliedTaxSerializer do
  subject(:serializer) { described_class.new(applied_tax, root_name: "applied_tax") }

  let(:applied_tax) { create(:credit_note_applied_tax) }

  before { applied_tax }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["applied_tax"]["lago_id"]).to eq(applied_tax.id)
    expect(result["applied_tax"]["lago_credit_note_id"]).to eq(applied_tax.credit_note_id)
    expect(result["applied_tax"]["lago_tax_id"]).to eq(applied_tax.tax_id)
    expect(result["applied_tax"]["tax_name"]).to eq(applied_tax.tax_name)
    expect(result["applied_tax"]["tax_code"]).to eq(applied_tax.tax_code)
    expect(result["applied_tax"]["tax_rate"]).to eq(applied_tax.tax_rate)
    expect(result["applied_tax"]["tax_description"]).to eq(applied_tax.tax_description)
    expect(result["applied_tax"]["amount_cents"]).to eq(applied_tax.amount_cents)
    expect(result["applied_tax"]["amount_currency"]).to eq(applied_tax.amount_currency)
    expect(result["applied_tax"]["created_at"]).to eq(applied_tax.created_at.iso8601)
  end
end
