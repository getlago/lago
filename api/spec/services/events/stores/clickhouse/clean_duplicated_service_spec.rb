# frozen_string_literal: true

require "spec_helper"

RSpec.describe Events::Stores::Clickhouse::CleanDuplicatedService, :clickhouse do
  subject(:clean_service) { described_class.new(subscription:, timestamp:) }

  let(:organization) { create(:organization, clickhouse_events_store: true) }
  let(:subscription) { create(:subscription, organization:) }
  let(:timestamp) { Time.current }

  # ReplacingMergeTree dedupes rows sharing the ORDER BY tuple at merge time, which prevents
  # the issue the service is supposed to clean.
  # TRUNCATE before each test gives us a clean slate (no inactive parts/mutations),
  # and inserting all rows in a single block with `optimize_on_insert=0` keeps every duplicate
  # inside the same data part so the engine has nothing to merge across.
  before do
    ::Clickhouse::EventsEnriched.connection.execute("TRUNCATE TABLE events_enriched")
  end

  def insert_enriched_events(rows)
    conn = ::Clickhouse::EventsEnriched.connection
    values = rows.map { |row|
      "(" + [
        conn.quote(row[:organization_id]),
        conn.quote(row[:external_subscription_id]),
        conn.quote(row[:code]),
        conn.quote(row[:timestamp].utc.strftime("%Y-%m-%d %H:%M:%S.%3N")),
        conn.quote(row[:transaction_id]),
        "{}",
        "'21.0'",
        conn.quote(row[:enriched_at].utc.strftime("%Y-%m-%d %H:%M:%S.%3N"))
      ].join(", ") + ")"
    }.join(", ")

    sql = <<~SQL.squish
      INSERT INTO events_enriched
        (organization_id, external_subscription_id, code, timestamp, transaction_id, properties, value, enriched_at)
      VALUES #{values}
    SQL

    conn.execute(sql, format: nil, settings: {optimize_on_insert: 0})
  end

  describe "#call" do
    let(:transaction_id) { SecureRandom.uuid }
    let(:timestamp) { Time.current.change(usec: 0) }
    let(:base_enriched_at) { Time.current.change(usec: 0) - 10.minutes }

    let(:duplicated_rows) do
      Array.new(3) do |i|
        {
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          transaction_id: transaction_id,
          timestamp: timestamp,
          code: "event_code",
          enriched_at: base_enriched_at + i.minutes
        }
      end
    end

    before do
      insert_enriched_events(duplicated_rows)
      allow(Subscriptions::ChargeCacheService).to receive(:expire_for_subscription)
    end

    it "removes duplicated events" do
      expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:).count).to eq(3)

      result = clean_service.call

      expect(result).to be_success
      expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:).count).to eq(1)

      event = ::Clickhouse::EventsEnriched.find_by(transaction_id:, timestamp:)
      expect(event.enriched_at).to match_datetime(base_enriched_at + 2.minutes)

      expect(Subscriptions::ChargeCacheService).to have_received(:expire_for_subscription).with(subscription)
    end

    context "when events share the same transaction_id but have different codes" do
      let(:other_code) { "other_event_code" }

      before do
        insert_enriched_events([{
          organization_id: organization.id,
          external_subscription_id: subscription.external_id,
          transaction_id: transaction_id,
          timestamp: timestamp,
          code: other_code,
          enriched_at: base_enriched_at
        }])
      end

      it "does not delete events with a different code" do
        result = clean_service.call

        expect(result).to be_success
        expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:, code: "event_code").count).to eq(1)
        expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:, code: other_code).count).to eq(1)
      end
    end

    context "when duplicate events share the same enriched_at timestamp" do
      let(:duplicated_rows) do
        Array.new(2) do
          {
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            transaction_id: transaction_id,
            timestamp: timestamp,
            code: "event_code",
            enriched_at: base_enriched_at
          }
        end
      end

      it "deletes all copies including the keeper" do
        expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:).count).to eq(2)

        result = clean_service.call

        expect(result).to be_success
        expect(::Clickhouse::EventsEnriched.where(transaction_id:, timestamp:).count).to eq(0)
      end
    end
  end
end
