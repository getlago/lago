# frozen_string_literal: true

module Events
  module Stores
    class StoreFactory
      OVERRIDE_KEY = :lago_event_store_override

      class << self
        def supports_clickhouse?
          ENV["LAGO_CLICKHOUSE_ENABLED"].present?
        end

        # Temporarily override the resolved store class and deduplication flag
        # for the duration of the given block. Used by tooling that needs to
        # exercise a different event store without persisting state on the
        # organization (e.g. the ClickHouse migration recipe).
        def with_override(store_class:, deduplicate:)
          raise "Events::Stores::StoreFactory override already active" if Thread.current[OVERRIDE_KEY]

          Thread.current[OVERRIDE_KEY] = {store_class:, deduplicate:}
          begin
            yield
          ensure
            Thread.current[OVERRIDE_KEY] = nil
          end
        end

        def override
          Thread.current[OVERRIDE_KEY]
        end
      end

      def self.store_class(organization:)
        return override[:store_class] if override

        event_store = Events::Stores::PostgresStore

        if supports_clickhouse? && organization.clickhouse_events_store?
          event_store = Events::Stores::ClickhouseStore

          if organization.feature_flag_enabled?(:enriched_events_aggregation)
            event_store = Events::Stores::ClickhouseEnrichedStore
          end
        end

        event_store
      end

      def self.new_instance(organization:, **kwargs)
        store_class(organization: organization).new(**kwargs)
      end
    end
  end
end
