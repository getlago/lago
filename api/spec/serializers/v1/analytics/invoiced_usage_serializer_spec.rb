# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Analytics::InvoicedUsageSerializer do
  subject(:serializer) { described_class.new(invoiced_usage, root_name: "invoiced_usage") }

  let(:invoiced_usage) do
    {
      "month" => Time.current.beginning_of_month.iso8601,
      "code" => "count_bm",
      "currency" => "EUR",
      "amount_cents" => 100
    }
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the gross revenue" do
    expect(result["invoiced_usage"]["month"]).to eq(Time.current.beginning_of_month.iso8601)
    expect(result["invoiced_usage"]["code"]).to eq("count_bm")
    expect(result["invoiced_usage"]["currency"]).to eq("EUR")
    expect(result["invoiced_usage"]["amount_cents"]).to eq(100)
  end
end
