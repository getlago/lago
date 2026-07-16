# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clickhouse::EventsEnriched, clickhouse: true do
  subject(:events_enriched) { create(:clickhouse_events_enriched) }

  it "persists a record via the factory" do
    expect(events_enriched).to be_persisted
  end

  describe ".table_name" do
    it "is events_enriched" do
      expect(described_class.table_name).to eq("events_enriched")
    end
  end

  describe ".primary_key" do
    it "matches the ClickHouse table primary key" do
      expect(described_class.primary_key).to eq(
        ["organization_id", "code", "external_subscription_id", "timestamp"]
      )
    end
  end
end
