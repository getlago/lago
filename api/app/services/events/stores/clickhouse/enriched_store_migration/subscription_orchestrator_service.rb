# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        # Drives a single subscription through the enriched store migration pipeline.
        # Called repeatedly — it reads the current state and executes the next step:
        #
        #   pending     → run initial comparison
        #   comparing   → if no diffs: completed (fast path)
        #                 if diffs + codes: reprocess events via Kafka, then wait for enrichment
        #                 if diffs + no codes: failed (unexpected mismatch)
        #   deduplicating → clean duplicate enriched_expanded rows
        #                   if ClickHouse times out: pause (queries saved for manual run)
        #                   otherwise: move to validation
        #   validating  → final comparison after reprocessing + dedup
        #                 if clean: completed; if diffs remain: failed
        #
        # On completion, enqueues the org-level OrchestratorJob to check overall progress.
        class SubscriptionOrchestratorService < BaseService
          CLEANUP_TIMEOUT = 5.minutes

          Result = BaseResult[:subscription_migration]

          def initialize(subscription_migration:)
            @subscription_migration = subscription_migration
            super
          end

          def call
            case subscription_migration.status
            when "pending"
              handle_pending
            when "comparing"
              handle_comparing
            when "deduplicating"
              handle_deduplicating
            when "validating"
              handle_validating
            else
              result.service_failure!(code: :invalid_status, message: "Unprocessable status: #{subscription_migration.status}")
            end

            result.subscription_migration = subscription_migration
            result
          end

          private

          attr_reader :subscription_migration

          delegate :subscription, to: :subscription_migration

          def handle_pending
            subscription_migration.start_comparing!
            handle_comparing
          end

          def handle_comparing
            comparison = run_comparison
            return unless comparison

            if comparison.diff_count.zero?
              subscription_migration.complete!
              enqueue_orchestrator
            elsif subscription_migration.billable_metric_codes.present?
              subscription_migration.start_reprocessing!
              reprocess_events
            else
              fail_migration!("Diffs found but no billable metric codes to reprocess")
            end
          end

          def handle_deduplicating
            dedup_result = ::Events::Stores::Clickhouse::CleanDuplicatedEnrichedExpandedService.call(
              subscription:,
              codes: subscription_migration.billable_metric_codes,
              timeout: CLEANUP_TIMEOUT
            )

            if dedup_result.failure?
              fail_migration!(dedup_result.error&.message || "Deduplication failed")
              return
            end

            if dedup_result.queries.present?
              subscription_migration.dedup_pending_queries = dedup_result.queries
              subscription_migration.pause_dedup!
            else
              subscription_migration.duplicates_removed_count = dedup_result.duplicated_count
              subscription_migration.start_validating!
              handle_validating
            end
          end

          def handle_validating
            comparison = run_comparison
            return unless comparison

            if comparison.diff_count.zero?
              subscription_migration.complete!
              enqueue_orchestrator
            else
              fail_migration!("Validation failed: #{comparison.diff_count} diff(s) remain after reprocessing")
            end
          end

          def run_comparison
            comparison = ::Events::Stores::Clickhouse::EnrichedStoreMigration::ComparisonService.call(subscription:)

            unless comparison.success?
              fail_migration!(comparison.error&.message || "Comparison failed")
              return
            end

            codes = comparison.fee_details
              .reject { |detail| detail.status == "match" }
              .filter_map(&:billable_metric_code)
              .uniq

            subscription_migration.update!(
              comparison_results: comparison.fee_details,
              billable_metric_codes: codes
            )

            comparison
          end

          def reprocess_events
            reprocess_result = ::Events::Stores::Clickhouse::ReEnrichSubscriptionEventsService.call(
              subscription:,
              codes: subscription_migration.billable_metric_codes
            )

            unless reprocess_result.success?
              fail_migration!(reprocess_result.error&.message || "Reprocessing failed")
              return
            end

            subscription_migration.events_reprocessed_count = reprocess_result.events_count
            subscription_migration.start_waiting!

            WaitForEnrichmentJob.perform_later(subscription_migration)
          rescue => e
            fail_migration!(e.message)
          end

          def fail_migration!(message)
            subscription_migration.update!(error_message: message)
            subscription_migration.fail!
          end

          def enqueue_orchestrator
            OrchestratorJob.perform_later(subscription_migration.enriched_store_migration)
          end
        end
      end
    end
  end
end
