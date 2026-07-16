# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        # After events are reprocessed and republished to Kafka, the enrichment pipeline
        # asynchronously produces rows in events_enriched_expanded. This service polls
        # ClickHouse to check whether all reprocessed events have been enriched.
        #
        # A single event can produce multiple enriched_expanded rows (one per charge on the
        # billable metric), so we count distinct transaction_ids rather than total rows.
        #
        # Returns :ready (advances to deduplicating), :not_ready (caller re-enqueues with
        # backoff), or :max_attempts_reached (marks the subscription migration as failed).
        class WaitForEnrichmentService < BaseService
          STATUSES = %i[ready not_ready max_attempts_reached].freeze
          MAX_ATTEMPTS = 10

          Result = BaseResult[:status, :enriched_count]

          def initialize(subscription_migration:, attempt:, max_attempts: MAX_ATTEMPTS)
            @subscription_migration = subscription_migration
            @attempt = attempt
            @max_attempts = max_attempts
            super
          end

          def call
            return result unless subscription_migration.waiting_for_enrichment?

            enriched_count = count_enriched_events
            result.enriched_count = enriched_count

            if enriched_count >= subscription_migration.events_reprocessed_count
              subscription_migration.update!(attempts: attempt)
              subscription_migration.start_deduplicating!
              SubscriptionOrchestratorJob.perform_later(subscription_migration)
              result.status = :ready
            elsif attempt >= max_attempts
              subscription_migration.update!(
                attempts: attempt,
                error_message: "Enrichment not ready after #{max_attempts} attempts " \
                               "(enriched: #{enriched_count}, expected: #{subscription_migration.events_reprocessed_count})"
              )
              subscription_migration.fail!
              result.status = :max_attempts_reached
            else
              subscription_migration.update!(attempts: attempt)
              result.status = :not_ready
            end

            result
          end

          private

          attr_reader :subscription_migration, :attempt, :max_attempts

          def count_enriched_events
            subscription = subscription_migration.subscription

            scope = ::Clickhouse::EventsEnrichedExpanded
              .where(organization_id: subscription.organization_id)
              .where(external_subscription_id: subscription.external_id)
              .where("timestamp >= ?", subscription.started_at)

            scope = scope.where("timestamp <= ?", subscription.terminated_at) if subscription.terminated?
            scope = scope.where(code: subscription_migration.billable_metric_codes) if subscription_migration.billable_metric_codes.present?

            scope.pick(Arel.sql("uniqExact(transaction_id)"))
          end
        end
      end
    end
  end
end
