# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        class WaitForEnrichmentJob < ApplicationJob
          queue_as "low_priority"

          BACKOFF_SCHEDULE = [5, 10].freeze
          DEFAULT_BACKOFF = 15

          def perform(subscription_migration, attempt = 1)
            check_result = WaitForEnrichmentService.call!(
              subscription_migration:,
              attempt:,
              max_attempts: WaitForEnrichmentService::MAX_ATTEMPTS
            )

            if check_result.status == :not_ready
              wait_minutes = BACKOFF_SCHEDULE[attempt - 1] || DEFAULT_BACKOFF
              self.class.set(wait: wait_minutes.minutes).perform_later(subscription_migration, attempt + 1)
            end
          end
        end
      end
    end
  end
end
