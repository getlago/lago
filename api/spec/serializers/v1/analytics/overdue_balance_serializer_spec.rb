# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Analytics::OverdueBalanceSerializer do
  subject(:serializer) { described_class.new(overdue_balance, root_name: "overdue_balance") }

  let(:overdue_balance) do
    {
      "month" => "2024-06-01T00:00:00Z",
      "amount_cents" => 100,
      "currency" => "EUR",
      "lago_invoice_ids" => "[\"1\", \"2\", \"3\"]",
      "billing_entity_id" => "be-id-1"
    }
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the overdue balance" do
    expect(result["overdue_balance"]).to eq(
      {
        "month" => "2024-06-01T00:00:00Z",
        "amount_cents" => 100,
        "currency" => "EUR",
        "lago_invoice_ids" => ["1", "2", "3"],
        "billing_entity_id" => "be-id-1"
      }
    )
  end
end
