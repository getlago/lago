# frozen_string_literal: true

require "rails_helper"

require_relative "shared_examples/an_event_store"

RSpec.describe Events::Stores::ClickhouseStore, clickhouse: {clean_before: true} do
  def create_event(timestamp:, value:, properties: {}, transaction_id: SecureRandom.uuid, code: billable_metric.code, charge_filter: nil, enriched_at: nil, event_charge: nil, created_at: nil)
    Clickhouse::EventsEnriched.create!(
      transaction_id: transaction_id,
      organization_id: organization.id,
      external_subscription_id: subscription.external_id,
      code:,
      timestamp: timestamp,
      properties: properties.merge(billable_metric.field_name => value).compact,
      value: value,
      decimal_value: value&.to_i&.to_d,
      precise_total_amount_cents: value,
      enriched_at: created_at || enriched_at || Time.current
    )
  end

  def create_enriched_event(timestamp:, value:, properties: {}, transaction_id: SecureRandom.uuid, code: billable_metric.code, charge_filter: nil, enriched_at: nil)
    Clickhouse::EventsEnrichedExpanded.create!(
      transaction_id:,
      organization_id: organization.id,
      external_subscription_id: subscription.external_id,
      subscription_id: subscription.id,
      plan_id: subscription.plan_id,
      code:,
      aggregation_type: billable_metric.aggregation_type,
      charge_id: charge.id,
      charge_version: charge.updated_at,
      charge_filter_id: charge_filter&.id,
      charge_filter_version: charge_filter&.updated_at,
      timestamp:,
      properties:,
      value:,
      decimal_value: value&.to_i&.to_d,
      precise_total_amount_cents: nil
    )
  end

  def format_timestamp(timestamp, precision: 3)
    Time.zone.parse(timestamp).strftime("%Y-%m-%d %H:%M:%S.%#{precision}L")
  end

  context "without deduplication" do
    it_behaves_like "an event store", with_event_duplication: false
  end

  context "with deduplication" do
    it_behaves_like "an event store"

    # Regression test for https://github.com/getlago/lago-api/pull/5359
    #
    # Two rows share the same (transaction_id, timestamp) but carry different
    # filterable properties. Deduplication via argMax(enriched_at) must resolve
    # to a single row FIRST — otherwise the same logical event could be counted
    # in multiple filter/group buckets (once per property value it ever had).
    describe "filters applied after deduplication" do
      subject(:event_store) do
        described_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries:,
          filters: {
            grouped_by: nil,
            grouped_by_values: nil,
            matching_filters: matching_filters,
            ignored_filters: [],
            charge_id: charge.id,
            charge_filter: nil
          },
          deduplicate: true
        )
      end

      let(:billable_metric) { create(:billable_metric, field_name: "value", code: "bm:code") }
      let(:organization) { billable_metric.organization }
      let(:charge) { create(:standard_charge, organization:, billable_metric:) }
      let(:customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, customer:, started_at: DateTime.parse("2023-03-15")) }
      let(:subscription_started_at) { subscription.started_at.beginning_of_day }
      let(:boundaries) do
        {
          from_datetime: subscription_started_at,
          to_datetime: subscription.started_at.end_of_month.end_of_day,
          charges_duration: 31
        }
      end

      let(:transaction_id) { SecureRandom.uuid }
      let(:timestamp) { subscription_started_at + 1.day }

      before do
        Clickhouse::EventsEnriched.create!(
          transaction_id:,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp:,
          properties: {"value" => 1, "region" => "europe"},
          value: 1,
          decimal_value: 1.to_d,
          precise_total_amount_cents: 1,
          enriched_at: 1.minute.ago
        )

        Clickhouse::EventsEnriched.create!(
          transaction_id:,
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          code: billable_metric.code,
          timestamp:,
          properties: {"value" => 1, "region" => "asia"},
          value: 1,
          decimal_value: 1.to_d,
          precise_total_amount_cents: 1,
          enriched_at: Time.current
        )
      end

      context "when the filter matches only the earlier (superseded) property value" do
        let(:matching_filters) { {"region" => ["europe"]} }

        it "does not count the event (latest enrichment is asia, filter excludes it)" do
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 0, events_count: 0))
        end
      end

      context "when the filter matches only the latest property value" do
        let(:matching_filters) { {"region" => ["asia"]} }

        it "counts the deduplicated event exactly once" do
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 1, events_count: 1))
        end
      end
    end
  end

  # Pins the query shape behind #count. The deduplicated + unfiltered count must
  # avoid the INNER ANY JOIN (which only fetches the value column and caused
  # ClickHouse OOM on large subscriptions); filtered and non-deduplicated counts
  # must keep using the JOIN-based path so the filter is applied to the latest
  # enriched row per dedup key.
  describe "#count_query" do
    subject(:event_store) do
      described_class.new(code: billable_metric.code, subscription:, boundaries:, filters:, deduplicate:)
    end

    let(:billable_metric) { create(:billable_metric, field_name: "value", code: "bm:code") }
    let(:organization) { billable_metric.organization }
    let(:charge) { create(:standard_charge, organization:, billable_metric:) }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:, started_at: DateTime.parse("2023-03-15")) }
    let(:boundaries) do
      {
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 31
      }
    end
    let(:deduplicate) { true }
    let(:filters) { {} }

    context "when deduplicated and unfiltered" do
      it "counts distinct dedup keys without a JOIN" do
        sql = event_store.count_query

        expect(sql).not_to include("JOIN")
        expect(sql).to include("GROUP BY #{described_class::DEDUP_KEY_COLUMNS.join(", ")}")
      end
    end

    context "when grouped_by_values is set" do
      let(:filters) { {grouped_by_values: {"region" => "europe"}} }

      it "uses the JOIN-based deduplication path" do
        expect(event_store.count_query).to include("INNER ANY JOIN")
      end
    end

    context "when matching_filters are set" do
      let(:filters) { {matching_filters: {"region" => ["europe"]}} }

      it "uses the JOIN-based deduplication path" do
        expect(event_store.count_query).to include("INNER ANY JOIN")
      end
    end

    context "when ignored_filters are set" do
      let(:filters) { {ignored_filters: [{"region" => ["europe"]}]} }

      it "uses the JOIN-based deduplication path" do
        expect(event_store.count_query).to include("INNER ANY JOIN")
      end
    end

    context "when deduplication is disabled" do
      let(:deduplicate) { false }

      it "does not build the deduplication CTEs" do
        sql = event_store.count_query

        expect(sql).not_to include("JOIN")
        expect(sql).not_to include("latest_enriched")
      end
    end

    context "when grouped_by is set without grouped_by_values or filters" do
      let(:filters) { {grouped_by: ["region"]} }

      it "still uses the JOIN-free fast path (grouped_by alone does not filter a count)" do
        expect(event_store.count_query).not_to include("JOIN")
      end
    end

    context "when use_from_boundary is false" do
      it "omits the lower timestamp bound without injecting NULL" do
        event_store.use_from_boundary = false
        sql = event_store.count_query

        expect(sql).not_to include("JOIN")
        expect(sql.upcase).not_to include("NULL")
        expect(sql).not_to include("timestamp >=")
        expect(sql).to include("timestamp <=")
      end
    end
  end

  # Real-data equivalence: the deduplicated + unfiltered #count uses the JOIN-free
  # fast path. These assert it returns the SAME number as the original JOIN-based
  # query on identical data, across re-enrichment duplicates and boundary edges.
  describe "#count fast-path equivalence with the JOIN-based query" do
    subject(:event_store) do
      described_class.new(code: billable_metric.code, subscription:, boundaries:, filters: {}, deduplicate: true)
    end

    let(:billable_metric) { create(:billable_metric, field_name: "value", code: "bm:code") }
    let(:organization) { billable_metric.organization }
    let(:charge) { create(:standard_charge, organization:, billable_metric:) }
    let(:customer) { create(:customer, organization:) }
    let(:subscription) { create(:subscription, customer:, started_at: DateTime.parse("2023-03-15")) }
    let(:boundaries) do
      {
        from_datetime: subscription.started_at.beginning_of_day,
        to_datetime: subscription.started_at.end_of_month.end_of_day,
        charges_duration: 31
      }
    end
    let(:ts) { subscription.started_at.beginning_of_day + 1.day }

    def insert_event(transaction_id:, timestamp:, enriched_at:, value: 1)
      Clickhouse::EventsEnriched.create!(
        transaction_id:,
        organization_id: organization.id,
        external_subscription_id: subscription.external_id,
        code: billable_metric.code,
        timestamp:,
        properties: {"value" => value},
        value:,
        decimal_value: value.to_d,
        precise_total_amount_cents: value,
        enriched_at:
      )
    end

    def join_based_count
      sql = event_store.send(
        :with_ctes,
        event_store.events_cte_queries(deduplicated_columns: %w[value]),
        "SELECT count()\nFROM events"
      )
      Events::Stores::Utils::ClickhouseConnection.connection_with_retry { |c| c.select_value(sql).to_i }
    end

    it "collapses re-enrichment duplicates of the same dedup key into one" do
      txn = SecureRandom.uuid
      insert_event(transaction_id: txn, timestamp: ts, enriched_at: 2.minutes.ago)
      insert_event(transaction_id: txn, timestamp: ts, enriched_at: 1.minute.ago)
      insert_event(transaction_id: txn, timestamp: ts, enriched_at: Time.current)
      insert_event(transaction_id: SecureRandom.uuid, timestamp: ts + 1.day, enriched_at: Time.current)

      expect(event_store.count.value).to eq(2)
      expect(event_store.count.value).to eq(join_based_count)
    end

    it "treats the same transaction_id at different timestamps as distinct events" do
      txn = SecureRandom.uuid
      insert_event(transaction_id: txn, timestamp: ts, enriched_at: Time.current)
      insert_event(transaction_id: txn, timestamp: ts + 1.hour, enriched_at: Time.current)

      expect(event_store.count.value).to eq(2)
      expect(event_store.count.value).to eq(join_based_count)
    end

    it "excludes events outside the boundaries" do
      insert_event(transaction_id: SecureRandom.uuid, timestamp: ts, enriched_at: Time.current)
      insert_event(transaction_id: SecureRandom.uuid, timestamp: boundaries[:to_datetime] + 2.days, enriched_at: Time.current)

      expect(event_store.count.value).to eq(1)
      expect(event_store.count.value).to eq(join_based_count)
    end

    it "returns zero when there are no events" do
      expect(event_store.count.value).to eq(0)
      expect(event_store.count.value).to eq(join_based_count)
    end
  end
end
