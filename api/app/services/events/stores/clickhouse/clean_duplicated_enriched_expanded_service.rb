# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      # This service cleans the duplicated events_enriched_expanded records that might have been created by
      # the execution of the events:reprocess rake task.
      # It uses ClickHouse lightweight `DELETE FROM` which is synchronous.
      # A timeout (in seconds) can be specified via the `timeout` parameter to avoid long-running queries.
      # When the query times out, the SQL is captured in `result.queries` for manual execution.
      class CleanDuplicatedEnrichedExpandedService < BaseService
        Result = BaseResult[:duplicated_count, :queries]

        def initialize(subscription:, codes: [], timeout: nil)
          @subscription = subscription
          @codes = codes
          @timeout = timeout

          super
        end

        def call
          result.queries = []
          result.duplicated_count = count_duplicates
          return result if result.duplicated_count.zero?

          delete_duplicated_events

          result
        end

        def count_duplicates
          sql = ActiveRecord::Base.sanitize_sql_for_conditions([
            <<~SQL.squish,
              SELECT count() AS duplicated_count FROM (#{duplicates_subquery})
            SQL
            sql_params
          ])

          row = Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
            connection.select_one(sql)
          end
          row["duplicated_count"].to_i
        end

        private

        attr_reader :subscription, :codes, :timeout

        def delete_duplicated_events
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              <<~SQL.squish,
                DELETE FROM events_enriched_expanded
                WHERE #{base_conditions}
                  AND (transaction_id, timestamp, charge_id, charge_filter_id, enriched_at)
                    NOT IN (#{keep_subquery})
                #{"SETTINGS max_execution_time=#{timeout.to_i}" if timeout.to_i.positive?}
              SQL
              sql_params
            ]
          )

          begin
            Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |conn|
              conn.execute(sql)
            end
          rescue Net::ReadTimeout
            result.queries << sql
          end
        end

        def base_conditions
          conditions = <<~SQL.squish
            organization_id = :organization_id
            AND subscription_id = :subscription_id
            AND timestamp >= :started_at
          SQL
          conditions += " AND code IN (:codes)" if codes.present?
          conditions
        end

        def duplicates_subquery
          <<~SQL.squish
            SELECT transaction_id, timestamp, charge_id, charge_filter_id
            FROM events_enriched_expanded
            WHERE #{base_conditions}
            GROUP BY transaction_id, timestamp, charge_id, charge_filter_id
            HAVING count() > 1
          SQL
        end

        def keep_subquery
          <<~SQL.squish
            SELECT transaction_id, timestamp, charge_id, charge_filter_id, max(enriched_at)
            FROM events_enriched_expanded
            WHERE #{base_conditions}
            GROUP BY transaction_id, timestamp, charge_id, charge_filter_id
          SQL
        end

        def sql_params
          {
            organization_id: subscription.organization_id,
            subscription_id: subscription.id,
            started_at: subscription.started_at,
            codes: codes
          }
        end
      end
    end
  end
end
