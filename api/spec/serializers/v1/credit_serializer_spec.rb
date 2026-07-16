# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::CreditSerializer do
  subject(:serializer) { described_class.new(credit, root_name: "credit") }

  let(:credit) { create(:credit) }
  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the object" do
    expect(result["credit"]["lago_id"]).to eq(credit.id)
    expect(result["credit"]["amount_cents"]).to eq(credit.amount_cents)
    expect(result["credit"]["amount_currency"]).to eq(credit.amount_currency)
    expect(result["credit"]["before_taxes"]).to eq(false)
    expect(result["credit"]["item"]["lago_item_id"]).to eq(credit.item_id)
    expect(result["credit"]["item"]["type"]).to eq("coupon")
    expect(result["credit"]["item"]["code"]).to eq(credit.coupon.code)
    expect(result["credit"]["item"]["name"]).to eq(credit.coupon.name)
    expect(result["credit"]["item"]["description"]).to eq(credit.coupon.description)
    expect(result["credit"]["invoice"]["payment_status"]).to eq(credit.invoice.payment_status)
    expect(result["credit"]["invoice"]["lago_id"]).to eq(credit.invoice.id)
  end

  context "with credit note credit" do
    let(:credit) do
      c = create(:credit_note_credit)
      c.credit_note.update!(description: "DESCRIPTION")
      c
    end

    it "serializes the object" do
      expect(result["credit"]["lago_id"]).to eq(credit.id)
      expect(result["credit"]["amount_cents"]).to eq(200)
      expect(result["credit"]["amount_currency"]).to eq("EUR")
      expect(result["credit"]["item"]["lago_item_id"]).to eq(credit.credit_note.id)
      expect(result["credit"]["item"]["type"]).to eq("credit_note")
      expect(result["credit"]["item"]["code"]).to eq(credit.credit_note.number)
      expect(result["credit"]["item"]["name"]).to eq(credit.credit_note.invoice.number)
      expect(result["credit"]["item"]["description"]).to eq("DESCRIPTION")
    end
  end
end
