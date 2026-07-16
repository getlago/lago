# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        class SubscriptionOrchestratorJob < ApplicationJob
          queue_as "low_priority"

          def perform(subscription_migration)
            SubscriptionOrchestratorService.call!(subscription_migration:)
          end
        end
      end
    end
  end
end
