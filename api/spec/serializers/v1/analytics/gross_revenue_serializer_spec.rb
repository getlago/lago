# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Analytics::GrossRevenueSerializer do
  subject(:serializer) { described_class.new(gross_revenue, root_name: "gross_revenue") }

  let(:gross_revenue) do
    {
      "month" => "2024-06-01T00:00:00Z",
      "amount_cents" => 100,
      "currency" => "EUR",
      "invoices_count" => 1,
      "billing_entity_id" => "be-id-1"
    }
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the gross revenue" do
    expect(result["gross_revenue"]).to eq(
      {
        "month" => "2024-06-01T00:00:00Z",
        "amount_cents" => 100,
        "currency" => "EUR",
        "invoices_count" => 1,
        "billing_entity_id" => "be-id-1"
      }
    )
  end
end
