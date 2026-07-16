# frozen_string_literal: true

require "spec_helper"

RSpec.describe Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService, :clickhouse do
  subject(:service) do
    described_class.new(
      subscription:,
      codes:,
      reprocess:,
      batch_size:,
      sleep_seconds: 0
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, status:, organization:, customer:, plan:, started_at: 1.month.ago, terminated_at:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:codes) { [] }
  let(:reprocess) { true }
  let(:batch_size) { 1000 }

  let(:kafka_producer) { instance_double(WaterDrop::Producer) }

  let(:status) { :active }
  let(:terminated_at) { nil }

  before do
    allow(Karafka).to receive(:producer).and_return(kafka_producer)
    allow(kafka_producer).to receive(:produce_many_async)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LAGO_KAFKA_RAW_EVENTS_TOPIC").and_return("test-topic")
  end

  describe "#call" do
    let!(:event) do
      create(
        :clickhouse_events_raw,
        organization:,
        subscription:,
        billable_metric:,
        external_customer_id: customer.external_id,
        timestamp: 2.weeks.ago,
        properties: {"key" => "value"},
        precise_total_amount_cents: "12.5"
      )
    end

    it "produces Kafka messages with expected payload structure" do
      result = service.call

      expect(result).to be_success
      expect(result.events_count).to eq(1)
      expect(result.batch_count).to eq(1)

      expect(kafka_producer).to have_received(:produce_many_async) do |messages|
        expect(messages.size).to eq(1)

        message = messages.first
        expect(message[:topic]).to eq("test-topic")
        expect(message[:key]).to eq("#{organization.id}-#{subscription.external_id}")

        payload = JSON.parse(message[:payload])
        expect(payload).to include(
          "organization_id" => organization.id,
          "external_customer_id" => customer.external_id,
          "external_subscription_id" => subscription.external_id,
          "transaction_id" => event.transaction_id,
          "code" => billable_metric.code,
          "precise_total_amount_cents" => "12.5",
          "properties" => {"key" => "value"},
          "source" => Events::KafkaProducerService::EVENT_SOURCE,
          "source_metadata" => {
            "reprocess" => true,
            "api_post_processed" => true
          }
        )
      end
    end

    context "with code filtering" do
      let(:codes) { [billable_metric.code] }
      let(:other_metric) { create(:billable_metric, organization:) }

      before do
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric: other_metric,
          external_customer_id: customer.external_id,
          timestamp: 2.weeks.ago
        )
      end

      it "only produces messages for matching codes" do
        result = service.call

        expect(result).to be_success
        expect(result.events_count).to eq(1)

        expect(kafka_producer).to have_received(:produce_many_async) do |messages|
          codes_in_messages = messages.map { |m| JSON.parse(m[:payload])["code"] }
          expect(codes_in_messages).to eq([billable_metric.code])
        end
      end
    end

    context "with terminated subscription" do
      let(:terminated_at) { 1.week.ago }
      let(:status) { :terminated }

      before do
        # Create events after terminated_at
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric:,
          external_customer_id: customer.external_id,
          timestamp: 1.day.ago
        )
      end

      it "excludes events after terminated_at" do
        result = service.call

        expect(result).to be_success
        expect(result.events_count).to eq(1)

        expect(kafka_producer).to have_received(:produce_many_async) do |messages|
          transaction_ids = messages.map { |m| JSON.parse(m[:payload])["transaction_id"] }
          expect(transaction_ids).to eq([event.transaction_id])
        end
      end
    end

    context "with reprocess set to false" do
      let(:reprocess) { false }

      it "reflects reprocess flag in source_metadata" do
        service.call

        expect(kafka_producer).to have_received(:produce_many_async) do |messages|
          payload = JSON.parse(messages.first[:payload])
          expect(payload["source_metadata"]["reprocess"]).to be(false)
        end
      end
    end

    context "with duplicated events" do
      let(:event_timestamp) { 2.weeks.ago }
      let(:shared_transaction_id) { SecureRandom.uuid }

      let!(:event) do
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric:,
          external_customer_id: customer.external_id,
          transaction_id: shared_transaction_id,
          timestamp: event_timestamp,
          ingested_at: 2.days.ago,
          properties: {"key" => "old_value"}
        )
      end

      before do
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric:,
          external_customer_id: customer.external_id,
          transaction_id: shared_transaction_id,
          timestamp: event_timestamp,
          ingested_at: 1.day.ago,
          properties: {"key" => "new_value"}
        )
      end

      it "only produces one message for the most recently ingested event" do
        result = service.call

        expect(result).to be_success
        expect(result.events_count).to eq(1)

        expect(kafka_producer).to have_received(:produce_many_async) do |messages|
          expect(messages.size).to eq(1)

          payload = JSON.parse(messages.first[:payload])
          expect(payload["properties"]).to eq({"key" => "new_value"})
        end
      end
    end

    context "with multiple batches" do
      let(:batch_size) { 1 }

      before do
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric:,
          external_customer_id: customer.external_id,
          timestamp: 1.week.ago
        )
      end

      it "produces correct counts" do
        result = service.call

        expect(result).to be_success
        expect(result.events_count).to eq(2)
        expect(result.batch_count).to eq(2)
        expect(kafka_producer).to have_received(:produce_many_async).twice
      end
    end

    context "with timestamp precision" do
      let(:timestamp) do
        time = subscription.started_at.dup
        time + 3.days + 0.299.seconds
      end

      let!(:event) do
        create(
          :clickhouse_events_raw,
          organization:,
          subscription:,
          billable_metric:,
          external_customer_id: customer.external_id,
          timestamp:,
          properties: {"key" => "value"},
          precise_total_amount_cents: "12.5"
        )
      end

      it "produces Kafka messages with expected payload structure" do
        result = service.call

        expect(result).to be_success
        expect(result.events_count).to eq(1)
        expect(result.batch_count).to eq(1)

        expect(kafka_producer).to have_received(:produce_many_async) do |messages|
          expect(messages.size).to eq(1)

          message = messages.first
          expect(message[:topic]).to eq("test-topic")
          expect(message[:key]).to eq("#{organization.id}-#{subscription.external_id}")

          payload = JSON.parse(message[:payload])
          expect(payload).to include(
            "organization_id" => organization.id,
            "external_customer_id" => customer.external_id,
            "external_subscription_id" => subscription.external_id,
            "transaction_id" => event.transaction_id,
            "timestamp" => timestamp.strftime("%s.%3N"),
            "code" => billable_metric.code,
            "precise_total_amount_cents" => "12.5",
            "properties" => {"key" => "value"},
            "source" => Events::KafkaProducerService::EVENT_SOURCE,
            "source_metadata" => {
              "reprocess" => true,
              "api_post_processed" => true
            }
          )
        end
      end
    end
  end
end
