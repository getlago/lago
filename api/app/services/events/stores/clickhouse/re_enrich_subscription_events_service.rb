# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      class ReEnrichSubscriptionEventsService < BaseService
        Result = BaseResult[:events_count, :batch_count]

        def initialize(subscription:, codes: [], reprocess: true, batch_size: 1000, sleep_seconds: 0.5)
          @subscription = subscription
          @codes = codes
          @reprocess = reprocess
          @batch_size = batch_size
          @sleep_seconds = sleep_seconds
          super
        end

        def call
          return result.service_failure!(code: "missing_kafka_topic", message: "LAGO_KAFKA_RAW_EVENTS_TOPIC env var is not set up") unless topic

          events_count = 0
          batches = 0

          deduplicated_scope.in_batches(of: batch_size, cursor: [:timestamp, :transaction_id]) do |batch|
            events = batch.to_a
            messages = events.map { |event| build_message(event) }

            Karafka.producer.produce_many_async(messages)

            batches += 1
            events_count += events.size

            sleep(sleep_seconds)
          end

          result.events_count = events_count
          result.batch_count = batches
          result
        end

        private

        attr_reader :subscription, :codes, :reprocess, :batch_size, :sleep_seconds

        def base_scope
          scope = ::Clickhouse::EventsRaw
            .where(organization_id: subscription.organization_id)
            .where(external_subscription_id: subscription.external_id)
            .where("timestamp >= ?", subscription.started_at)

          scope = scope.where("timestamp <= ?", subscription.terminated_at) if subscription.terminated?
          scope = scope.where(code: codes) if codes.present?

          scope
        end

        def deduplicated_scope
          deduplicated_sql = base_scope.to_sql + " ORDER BY ingested_at DESC LIMIT 1 BY transaction_id, timestamp"
          ::Clickhouse::EventsRaw.from("(#{deduplicated_sql}) AS events_raw")
        end

        def topic
          @topic ||= ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"]
        end

        def build_message(event)
          {
            topic:,
            key: "#{event.organization_id}-#{event.external_subscription_id}",
            payload: build_payload(event).to_json
          }
        end

        def build_payload(event)
          properties = event.properties
          properties = JSON.parse(properties) if properties.is_a?(String)

          {
            organization_id: event.organization_id,
            external_customer_id: event.external_customer_id,
            external_subscription_id: event.external_subscription_id,
            transaction_id: event.transaction_id,
            timestamp: event.timestamp.strftime("%s.%3N"),
            code: event.code,
            precise_total_amount_cents: event.precise_total_amount_cents.present? ? event.precise_total_amount_cents.to_s : "0.0",
            properties:,
            ingested_at: Time.zone.now.iso8601[...-1],
            source: Events::KafkaProducerService::EVENT_SOURCE,
            source_metadata: {
              api_post_processed: true,
              reprocess:
            }
          }
        end
      end
    end
  end
end
