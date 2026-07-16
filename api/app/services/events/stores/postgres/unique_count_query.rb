# frozen_string_literal: true

module Events
  module Stores
    module Postgres
      class UniqueCountQuery
        def initialize(store:)
          @store = store
        end

        def query
          # NOTE: First sum calculates all operation values for a specific property
          # (for instance 2 relevant additions with 1 relevant removal [0, 1, 0, -1, 1] returns 1)
          # The next sum combines all properties into a single result
          <<-SQL
            #{events_cte_sql},
            event_values AS (
              SELECT
                property,
                SUM(adjusted_value) AS sum_adjusted_value
              FROM (
                SELECT
                  timestamp,
                  property,
                  operation_type,
                  #{operation_value_sql} AS adjusted_value
                FROM events_data
                ORDER BY timestamp ASC
              ) adjusted_event_values
              GROUP BY property
            )

            SELECT COALESCE(SUM(sum_adjusted_value), 0) AS aggregation FROM event_values
          SQL
        end

        def prorated_query
          <<-SQL
            #{events_cte_sql},
            -- ignore if for remove event there is a following add event the same day that nullifies this one
            same_day_ignored AS (
              SELECT
                property,
                operation_type,
                timestamp,
                #{ignore_remove_events_sql} AS is_ignored
              FROM events_data as e
            ),
            -- Check if the operation type is the same as previous, so it nullifies this one
            event_values AS (
              SELECT
                property,
                operation_type,
                timestamp
              FROM (
                SELECT
                  timestamp,
                  property,
                  operation_type,
                  #{operation_value_sql} AS adjusted_value
                FROM same_day_ignored
                WHERE is_ignored = false
                ORDER BY timestamp ASC
              ) adjusted_event_values
              WHERE adjusted_value != 0 -- adjusted_value = 0 does not impact the total
              GROUP BY property, operation_type, timestamp
            )

            SELECT COALESCE(SUM(period_ratio), 0) as aggregation
            FROM (
              SELECT (#{period_ratio_sql}) AS period_ratio
              FROM event_values
            ) cumulated_ratios
          SQL
        end

        def grouped_query
          <<-SQL
            #{grouped_events_cte_sql},

            event_values AS (
              SELECT
                #{group_names.join(", ")},
                property,
                SUM(adjusted_value) AS sum_adjusted_value
              FROM (
                SELECT
                  timestamp,
                  property,
                  operation_type,
                  #{group_names.join(", ")},
                  #{grouped_operation_value_sql} AS adjusted_value
                FROM events_data
                ORDER BY timestamp ASC
              ) adjusted_event_values
              GROUP BY #{group_names.join(", ")}, property
            )

            SELECT
              #{group_names.join(", ")},
              COALESCE(SUM(sum_adjusted_value), 0) as aggregation
            FROM event_values
            GROUP BY #{group_names.join(", ")}
          SQL
        end

        def grouped_prorated_query
          <<-SQL
            #{grouped_events_cte_sql},
            -- ignore if for remove event there is a following add event the same day (for grouped events) that nullifies this one
            same_day_ignored AS (
              SELECT
                #{group_names.join(", ")},
                property,
                operation_type,
                timestamp,
                #{ignore_remove_grouped_events_sql} AS is_ignored
              FROM (
                SELECT
                  #{group_names.join(", ")},
                  property,
                  operation_type,
                  timestamp
                FROM events_data
                ORDER BY timestamp ASC
              ) as e
            ),
            -- Check if the operation type is the same as previous, so it nullifies this one
            event_values AS (
              SELECT
                #{group_names.join(", ")},
                property,
                operation_type,
                timestamp
              FROM (
                SELECT
                  timestamp,
                  property,
                  operation_type,
                  #{group_names.join(", ")},
                  #{grouped_operation_value_sql} AS adjusted_value
                FROM same_day_ignored
                WHERE is_ignored = false
                ORDER BY timestamp ASC
              ) adjusted_event_values
              WHERE adjusted_value != 0 -- adjusted_value = 0 does not impact the total
              GROUP BY #{group_names.join(", ")}, property, operation_type, timestamp
              ORDER BY timestamp ASC
            )

            SELECT
              #{group_names.join(", ")},
              COALESCE(SUM(period_ratio), 0) as aggregation
            FROM (
              SELECT
                (#{grouped_period_ratio_sql}) AS period_ratio,
                #{group_names.join(", ")}
              FROM event_values
            ) cumulated_ratios
            GROUP BY #{group_names.join(", ")}
          SQL
        end

        # NOTE: Not used in production, only for debug purpose to check the computed values before aggregation
        # Returns an array of event's timestamp, property, operation type and operation value
        # Example:
        # [
        #   ["2023-03-16T00:00:00.000Z", "001", "add", 1],
        #   ["2023-03-17T00:00:00.000Z", "001", "add", 0],
        #   ["2023-03-17T10:00:00.000Z", "002", "remove", 0],
        #   ["2023-03-18T00:00:00.000Z", "001", "remove", -1],
        #   ["2023-03-19T00:00:00.000Z", "002", "add", 1]
        # ]
        def breakdown_query
          <<-SQL
            #{events_cte_sql}

            SELECT
              timestamp,
              property,
              operation_type,
              #{operation_value_sql}
            FROM events_data
            ORDER BY timestamp ASC
          SQL
        end

        def prorated_breakdown_query(with_remove: false)
          <<-SQL
            #{events_cte_sql},
            -- ignore if for remove event there is a following add event the same day that nullifies this one
            same_day_ignored AS (
              SELECT
                property,
                operation_type,
                timestamp,
                #{ignore_remove_events_sql} AS is_ignored
              FROM events_data as e
            ),
            -- Check if the operation type is repeated, so it nullifies this one at the same day
            event_values AS (
              SELECT
                property,
                operation_type,
                timestamp
              FROM (
                SELECT
                  timestamp,
                  property,
                  operation_type,
                  #{operation_value_sql} AS adjusted_value
                FROM same_day_ignored
                WHERE is_ignored = false
                ORDER BY timestamp ASC
              ) adjusted_event_values
              WHERE adjusted_value != 0 -- adjusted_value = 0 does not impact the total
              GROUP BY property, timestamp, operation_type
            )

            SELECT
              prorated_value,
              timestamp,
              property,
              operation_type
            FROM (
              SELECT
                (#{period_ratio_sql}) AS prorated_value,
                timestamp,
                property,
                operation_type
              FROM event_values
            ) prorated_breakdown
            #{"WHERE prorated_value != 0" unless with_remove}
            ORDER BY timestamp ASC, property ASC
          SQL
        end

        private

        attr_reader :store

        delegate :events, :charges_duration, :sanitized_property_name, :operation_type_sql, to: :store

        def events_cte_sql
          # NOTE: Common table expression returning event's timestamp, property name and operation type.
          <<-SQL
            WITH events_data AS (#{
              events(ordered: true)
                .select(
                  "timestamp, \
                  #{sanitized_property_name} AS property, \
                  #{operation_type_sql} AS operation_type"
                ).to_sql
            })
          SQL
        end

        def grouped_events_cte_sql
          groups = store.grouped_by.map.with_index do |group, index|
            "#{sanitized_property_name(group)} AS g_#{index}"
          end

          <<-SQL
            WITH events_data AS (#{
              events(ordered: true)
                .select(
                  "#{groups.join(", ")}, \
                  timestamp, \
                  #{sanitized_property_name} AS property, \
                  #{operation_type_sql} AS operation_type"
                ).to_sql
            })
          SQL
        end

        def operation_value_sql
          # NOTE: Returns 1 for relevant addition, -1 for relevant removal
          # If property already added, another addition returns 0 ; it returns 1 otherwise
          # If property already removed or not yet present, another removal returns 0 ; it returns -1 otherwise
          <<-SQL
            CASE
            WHEN LAG(operation_type, 1, 'remove') OVER (PARTITION BY property ORDER BY timestamp) = operation_type
            THEN 0 -- NOTE: if the first ever operation is a remove, it's not relevant; note that it's "remove" if not found, so we ignore "empty" remove
            ELSE CASE WHEN operation_type = 'add' THEN 1 ELSE -1 END
            END
          SQL
        end

        def grouped_operation_value_sql
          # NOTE: Returns 1 for relevant addition, -1 for relevant removal
          # If property already added, another addition returns 0 ; it returns 1 otherwise
          # If property already removed or not yet present, another removal returns 0 ; it returns -1 otherwise
          <<-SQL
            CASE
            WHEN LAG(operation_type, 1, 'remove') OVER (PARTITION BY #{group_names.join(", ")}, property ORDER BY timestamp) = operation_type
            THEN 0 -- NOTE: if the first ever operation is a remove, it's not relevant; note that it's "remove" if not found, so we ignore "empty" remove
            ELSE CASE WHEN operation_type = 'add' THEN 1 ELSE -1 END
            END
          SQL
        end

        def period_ratio_sql
          <<-SQL
            CASE WHEN operation_type = 'add'
            THEN
              -- NOTE: duration in seconds between current event and next one - using end of period as final boundaries
              (
                (
                  DATE((
                    -- NOTE: if following event is older than the start of the period, we use the start of the period as the reference
                    CASE WHEN (LEAD(timestamp, 1, :to_datetime) OVER (PARTITION BY property ORDER BY timestamp)) < :from_datetime
                    THEN :from_datetime
                    ELSE LEAD(timestamp, 1, :to_datetime) OVER (PARTITION BY property ORDER BY timestamp) + interval '1' day
                    END
                  )::timestamptz AT TIME ZONE :timezone)
                  - DATE((
                    -- NOTE: if events is older than the start of the period, we use the start of the period as the reference
                    CASE WHEN timestamp < :from_datetime THEN :from_datetime ELSE timestamp END
                  )::timestamptz AT TIME ZONE :timezone)
                )::numeric
              )
              /
              -- NOTE: full duration of the period
              #{charges_duration || 1}::numeric
            ELSE
              0 -- NOTE: duration was null so usage is null
            END
          SQL
        end

        def grouped_period_ratio_sql
          <<-SQL
            CASE WHEN operation_type = 'add'
            THEN
              -- NOTE: duration in seconds between current event and next one - using end of period as final boundaries
              (
                (
                  DATE((
                    -- NOTE: if following event is older than the start of the period, we use the start of the period as the reference
                    CASE WHEN (LEAD(timestamp, 1, :to_datetime) OVER (PARTITION BY #{group_names.join(", ")}, property ORDER BY timestamp)) < :from_datetime
                    THEN :from_datetime
                    ELSE LEAD(timestamp, 1, :to_datetime) OVER (PARTITION BY #{group_names.join(", ")}, property ORDER BY timestamp)
                    END
                  )::timestamptz AT TIME ZONE :timezone)
                  - DATE((
                    -- NOTE: if events is older than the start of the period, we use the start of the period as the reference
                    CASE WHEN timestamp < :from_datetime THEN :from_datetime ELSE timestamp END
                  )::timestamptz AT TIME ZONE :timezone)
                )::numeric
                + 1
              )
              /
              -- NOTE: full duration of the period
              #{charges_duration || 1}::numeric
            ELSE
              0 -- NOTE: duration was null so usage is null
            END
          SQL
        end

        def ignore_remove_events_sql
          <<-SQL
            CASE
              -- we do not ignore ADDs, if they are duplicated they'll be cleaned by adjusted value calculation
              WHEN operation_type = 'add' THEN false
              -- if there is a next event the same day is the opposite operation type, this should be ignored
              WHEN #{existing_event_opposite_operation_type_sql} THEN true
              ELSE false
            END
          SQL
        end

        def ignore_remove_grouped_events_sql
          <<-SQL
            CASE
              -- we do not ignore ADDs, if they are duplicated they'll be cleaned by adjusted value calculation
              WHEN operation_type = 'add' THEN false
              -- if the next event the same day is the opposite operation type, it should be ignored
              WHEN #{existing_grouped_event_opposite_operation_type_sql} THEN true
              ELSE false
            END
          SQL
        end

        # IS_IGNORED logic for prorated aggregation desired behaviour is:
        # 27th property add
        # 27th property remove
        # 27th property add

        # 28th property add (operation is 0, so it's already filtered by previous query)
        # 28th property remove
        # --- end of unit 0, prorated 2 days
        # 30th property add
        # --the result of 30 is 1 -> prorated 1 day
        # for this we want to have only 2 events: 27th-28th and 30th to 30th

        # summary table:
        # 27th property add not_ignore
        # 27th property remove ignore
        # 27th property add ignore
        # 28th property remove not_ignore
        # 30th property add not_ignore
        # So the rule is:
        # -- for the same day, we look at next event. if it's opposite of current, current can be ignored
        # -- we look at previous not ignored event. if the operation type matches. we can ignore current
        def existing_event_opposite_operation_type_sql
          <<-SQL
            (
              SELECT
                1
              FROM events_data next_event
              WHERE next_event.property = e.property
                AND DATE((next_event.timestamp)::timestamptz AT TIME ZONE :timezone) = DATE((e.timestamp)::timestamptz AT TIME ZONE :timezone)
                AND next_event.operation_type <> e.operation_type
                AND next_event.timestamp > e.timestamp
              LIMIT 1
            ) = 1
          SQL
        end

        def existing_grouped_event_opposite_operation_type_sql
          <<-SQL
            (
              SELECT
                1
              FROM events_data next_event
              WHERE next_event.property = e.property
                AND #{group_names.map { |name| "next_event.#{name} = e.#{name}" }.join(" AND ")}
                AND DATE((next_event.timestamp)::timestamptz AT TIME ZONE :timezone) = DATE((e.timestamp)::timestamptz AT TIME ZONE :timezone)
                AND next_event.operation_type <> e.operation_type
                AND next_event.timestamp > e.timestamp
              LIMIT 1
            ) = 1
          SQL
        end

        def group_names
          @group_names ||= store.grouped_by.map.with_index { |_, index| "g_#{index}" }
        end
      end
    end
  end
end
