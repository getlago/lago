# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      module EnrichedStoreMigration
        class OrchestratorJob < ApplicationJob
          queue_as "low_priority"

          def perform(enriched_store_migration)
            # TODO: Implement in step 4 — calls OrchestratorService
          end
        end
      end
    end
  end
end
