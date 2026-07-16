# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clickhouse::EventsEnrichedExpanded, clickhouse: true do
  subject(:events_enriched_expanded) { create(:clickhouse_events_enriched_expanded) }

  it "persists a record via the factory" do
    expect(events_enriched_expanded).to be_persisted
  end

  describe ".table_name" do
    it "is events_enriched_expanded" do
      expect(described_class.table_name).to eq("events_enriched_expanded")
    end
  end

  describe ".primary_key" do
    it "matches the ClickHouse table primary key" do
      expect(described_class.primary_key).to eq(
        ["organization_id", "code", "external_subscription_id", "charge_id", "charge_filter_id", "timestamp"]
      )
    end
  end
end
