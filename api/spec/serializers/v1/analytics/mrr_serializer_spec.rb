# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Analytics::MrrSerializer do
  subject(:serializer) { described_class.new(mrr, root_name: "mrr") }

  let(:mrr) do
    {
      "month" => Time.current.beginning_of_month.iso8601,
      "amount_cents" => 100,
      "currency" => "EUR"
    }
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the gross revenue" do
    expect(result["mrr"]["month"]).to eq(Time.current.beginning_of_month.iso8601)
    expect(result["mrr"]["amount_cents"]).to eq(100)
    expect(result["mrr"]["currency"]).to eq("EUR")
  end
end
