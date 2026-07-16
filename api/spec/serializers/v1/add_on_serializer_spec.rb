# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::AddOnSerializer do
  subject(:serializer) { described_class.new(add_on, root_name: "add_on") }

  let(:add_on) { create(:add_on) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["add_on"]["lago_id"]).to eq(add_on.id)
    expect(result["add_on"]["name"]).to eq(add_on.name)
    expect(result["add_on"]["invoice_display_name"]).to eq(add_on.invoice_display_name)
    expect(result["add_on"]["code"]).to eq(add_on.code)
    expect(result["add_on"]["amount_cents"]).to eq(add_on.amount_cents)
    expect(result["add_on"]["amount_currency"]).to eq(add_on.amount_currency)
    expect(result["add_on"]["description"]).to eq(add_on.description)
    expect(result["add_on"]["created_at"]).to eq(add_on.created_at.iso8601)
  end
end
