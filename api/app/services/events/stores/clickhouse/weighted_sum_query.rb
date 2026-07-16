# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      class WeightedSumQuery
        def initialize(store:)
          @store = store
        end

        def query
          with_ctes(events_cte_sql, <<-SQL)
            SELECT
              sum(period_ratio) as aggregation,
              sum(difference) as variation_with_initial,
              count() as rows_count
            FROM (
              SELECT (#{period_ratio_sql}) as period_ratio, difference
              FROM events_data
            ) cumulated_ratios
          SQL
        end

        def grouped_query(initial_values:)
          with_ctes(grouped_events_cte_sql(initial_values), <<-SQL)
            SELECT
              #{joined_group_names},
              SUM(period_ratio) as aggregation,
              sum(difference) as variation_with_initial,
              count() as rows_count
            FROM (
              SELECT
                #{joined_group_names},
                (#{grouped_period_ratio_sql}) AS period_ratio,
                difference
              FROM events_data
            ) cumulated_ratios
            GROUP BY #{joined_group_names}
          SQL
        end

        # NOTE: not used in production, only for debug purpose to check the computed values before aggregation
        def breakdown_query
          with_ctes(events_cte_sql, <<-SQL)
            SELECT
              timestamp,
              difference,
              SUM(difference) OVER (ORDER BY timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumul,
              date_diff('seconds', timestamp, leadInFrame(timestamp, 1, toDateTime64(:to_datetime, 5, 'UTC')) OVER (ORDER BY timestamp ASC ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) AS second_duration,
              (#{period_ratio_sql}) AS period_ratio
            FROM events_data
            ORDER BY timestamp ASC
          SQL
        end

        private

        attr_reader :store

        delegate :arel_table,
          :with_ctes,
          :charges_duration,
          :decimal_literal,
          :events_cte_queries,
          :grouped_by_columns,
          :grouped_arel_columns,
          to: :store

        def group_names
          _, names = grouped_arel_columns

          if names.is_a?(Array)
            return names
          end

          names.to_s.split(",")
        end

        def joined_group_names
          group_names.join(", ")
        end

        def events_cte_sql
          events_cte = events_cte_queries(
            ordered: true,
            select: [
              arel_table[:timestamp].as("timestamp"),
              arel_table[:decimal_value].as("difference")
            ],
            deduplicated_columns: %w[decimal_value]
          )

          events_data = <<~SQL
            (#{initial_value_sql})
            UNION ALL
            (#{events_cte["events"]})
            UNION ALL
            (#{end_of_period_value_sql})
          SQL

          events_cte.except!("events").merge!("events_data" => events_data)
        end

        def initial_value_sql
          <<-SQL
            SELECT
              toDateTime64(:from_datetime, 5, 'UTC') as timestamp,
              toDecimal128(:initial_value, :decimal_scale) as difference
          SQL
        end

        def end_of_period_value_sql
          <<-SQL
            SELECT
              toDateTime64(:to_datetime, 5, 'UTC') as timestamp,
              toDecimal128(0, :decimal_scale) as difference
          SQL
        end

        def period_ratio_sql
          <<-SQL
            if(
              -- NOTE: duration in seconds between current event and next one - or end of period if next event is null
              date_diff('seconds', timestamp, leadInFrame(timestamp, 1, toDateTime64(:to_datetime, 5, 'UTC')) OVER (ORDER BY timestamp ASC ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) > 0,

              -- NOTE: cumulative sum from previous events in the period
              (SUM(difference) OVER (ORDER BY timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))
              *
              -- NOTE: duration in seconds between current event and next one - or end of period if next event is null
              date_diff('seconds', timestamp, leadInFrame(timestamp, 1, toDateTime64(:to_datetime, 5, 'UTC')) OVER (ORDER BY timestamp ASC ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING))
              /
              -- NOTE: full duration of the period
              #{charges_duration.days.to_i}
              ,
              -- NOTE: duration was null so usage is null
              0
            )
          SQL
        end

        def grouped_events_cte_sql(initial_values)
          groups, _ = grouped_arel_columns
          events_cte = events_cte_queries(
            ordered: true,
            select: groups + [
              arel_table[:timestamp].as("timestamp"),
              arel_table[:decimal_value].as("difference")
            ],
            deduplicated_columns: store.with_presentation_by_in_grouped_by? ? %w[decimal_value sorted_properties] : %w[decimal_value]
          )

          events_data = <<-SQL
            (#{grouped_initial_value_sql(initial_values)})
            UNION ALL
            (#{events_cte["events"]})
            UNION ALL
            (#{grouped_end_of_period_value_sql(initial_values)})
          SQL

          events_cte.except!("events").merge!("events_data" => events_data)
        end

        def grouped_initial_value_sql(initial_values)
          values = initial_values.map do |initial_value|
            groups = grouped_by_columns(initial_value[:groups])

            [
              groups,
              "toDateTime64(:from_datetime, 5, 'UTC')",
              "toDecimal128('#{decimal_literal(initial_value[:value])}', :decimal_scale)"
            ].flatten.join(", ")
          end

          <<-SQL
            SELECT
              #{Array.new(store.grouped_by_count) { |index| "tuple.#{index + 1} AS #{group_names[index]}" }.join(", ")},
              tuple.#{store.grouped_by_count + 1} AS timestamp,
              tuple.#{store.grouped_by_count + 2} AS difference
            FROM ( SELECT arrayJoin([#{values.map { "tuple(#{it})" }.join(", ")}]) AS tuple )
          SQL
        end

        def grouped_end_of_period_value_sql(initial_values)
          values = initial_values.map do |initial_value|
            groups = grouped_by_columns(initial_value[:groups])

            [
              groups,
              "toDateTime64(:to_datetime, 5, 'UTC')",
              "toDecimal32(0, 0)"
            ].flatten.join(", ")
          end

          <<-SQL
            SELECT
              #{Array.new(store.grouped_by_count) { |index| "tuple.#{index + 1} AS #{group_names[index]}" }.join(", ")},
              tuple.#{store.grouped_by_count + 1} AS timestamp,
              tuple.#{store.grouped_by_count + 2} AS difference
            FROM ( SELECT arrayJoin([#{values.map { "tuple(#{it})" }.join(", ")}]) AS tuple )
          SQL
        end

        def grouped_period_ratio_sql
          <<-SQL
            if(
              -- NOTE: duration in seconds between current event and next one - or end of period if next event is null
              date_diff('seconds', timestamp, leadInFrame(timestamp, 1, toDateTime64(:to_datetime, 5, 'UTC')) OVER (PARTITION BY #{joined_group_names} ORDER BY timestamp ASC ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)) > 0,

              -- NOTE: cumulative sum from previous events in the period
              (SUM(difference) OVER (PARTITION BY #{joined_group_names} ORDER BY timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))
              *
              -- NOTE: duration in seconds between current event and next one - or end of period if next event is null
              date_diff('seconds', timestamp, leadInFrame(timestamp, 1, toDateTime64(:to_datetime, 5, 'UTC')) OVER (PARTITION BY #{joined_group_names} ORDER BY timestamp ASC ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING))
              /
              -- NOTE: full duration of the period
              #{charges_duration.days.to_i}
              ,
              -- NOTE: duration was null so usage is null
              0
            )
          SQL
        end
      end
    end
  end
end
