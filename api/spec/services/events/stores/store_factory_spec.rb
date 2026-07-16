# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::Stores::StoreFactory do
  subject(:store_instance) { described_class.new_instance(organization:, **arguments) }

  let(:organization) { create(:organization, clickhouse_events_store:, feature_flags:) }
  let(:clickhouse_events_store) { false }
  let(:feature_flags) { [] }

  let(:arguments) do
    time = Time.current

    {
      subscription: create(:subscription, organization:),
      boundaries: {
        from_datetime: time.beginning_of_month,
        to_datetime: time.end_of_month,
        period_duration: time.end_of_month.day
      },
      code: "some_bm_code",
      filters: {}
    }
  end

  describe "#new_instance" do
    it "returns an instance of a Postgres store" do
      expect(store_instance).to be_a(Events::Stores::PostgresStore)
    end

    context "when clickhouse is enabled" do
      around do |example|
        previous_value = ENV["LAGO_CLICKHOUSE_ENABLED"]
        ENV["LAGO_CLICKHOUSE_ENABLED"] = "true"
        example.run
        ENV["LAGO_CLICKHOUSE_ENABLED"] = previous_value
      end

      it "returns an instance of a Postgres store" do
        expect(store_instance).to be_a(Events::Stores::PostgresStore)
      end

      context "when organization has the clickhoise flag" do
        let(:clickhouse_events_store) { true }

        it "returns an instance of a Clickhouse store" do
          expect(store_instance).to be_a(Events::Stores::ClickhouseStore)
        end

        context "when enriched_events_aggregation feature flag is enabled" do
          let(:feature_flags) { ["enriched_events_aggregation"] }

          it "returns an instance of a ClickhouseEnrichedStore" do
            expect(store_instance).to be_a(Events::Stores::ClickhouseEnrichedStore)
          end
        end
      end
    end
  end

  describe ".with_override" do
    it "forces the store class for the duration of the block" do
      described_class.with_override(store_class: Events::Stores::ClickhouseStore, deduplicate: true) do
        expect(described_class.store_class(organization:)).to eq(Events::Stores::ClickhouseStore)
        expect(described_class.override).to eq(store_class: Events::Stores::ClickhouseStore, deduplicate: true)
      end
    end

    it "clears the override after the block returns" do
      described_class.with_override(store_class: Events::Stores::ClickhouseStore, deduplicate: true) {}
      expect(described_class.override).to be_nil
    end

    it "clears the override when the block raises" do
      expect {
        described_class.with_override(store_class: Events::Stores::ClickhouseStore, deduplicate: true) { raise "boom" }
      }.to raise_error("boom")
      expect(described_class.override).to be_nil
    end

    it "raises when nested" do
      described_class.with_override(store_class: Events::Stores::ClickhouseStore, deduplicate: true) do
        expect {
          described_class.with_override(store_class: Events::Stores::PostgresStore, deduplicate: false) {}
        }.to raise_error("Events::Stores::StoreFactory override already active")
        expect(described_class.override).to eq(store_class: Events::Stores::ClickhouseStore, deduplicate: true)
      end
    end
  end
end
