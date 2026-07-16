# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::EventEnrichedSerializer, clickhouse: true do
  subject(:serializer) { described_class.new(event, root_name: "event") }

  let(:event) do
    create(
      :clickhouse_events_enriched,
      transaction_id: "tx_123",
      external_subscription_id: "sub_456",
      code: "api_call",
      timestamp: Time.zone.parse("2024-01-15T10:30:45.123Z"),
      enriched_at: Time.zone.parse("2024-01-15T10:30:50.456Z"),
      value: "42.5",
      decimal_value: BigDecimal("42.5"),
      precise_total_amount_cents: BigDecimal("1234.567"),
      properties: {region: "us-east-1"}
    )
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the enriched event" do
    expect(result["event"]).to include(
      "transaction_id" => "tx_123",
      "external_subscription_id" => "sub_456",
      "code" => "api_call",
      "timestamp" => "2024-01-15T10:30:45.123Z",
      "enriched_at" => "2024-01-15T10:30:50.456Z",
      "value" => "42.5",
      "decimal_value" => "42.5",
      "precise_total_amount_cents" => "1234.567",
      "properties" => {"region" => "us-east-1"}
    )
  end

  context "when enriched_at is nil" do
    let(:event) { create(:clickhouse_events_enriched, enriched_at: nil) }

    it "serializes enriched_at as nil" do
      expect(result["event"]["enriched_at"]).to be_nil
    end
  end

  context "when precise_total_amount_cents is nil" do
    let(:event) { create(:clickhouse_events_enriched, precise_total_amount_cents: nil) }

    it "serializes precise_total_amount_cents as nil" do
      expect(result["event"]["precise_total_amount_cents"]).to be_nil
    end
  end
end
