# frozen_string_literal: true

module Events
  module Stores
    class ClickhouseStore < BaseStore
      include Events::Stores::Utils::QueryHelpers
      include Events::Stores::Utils::ClickhouseSqlHelpers

      # Give ClickHouse time to consume and merge the `events_enriched` event
      # processed on the events processor side
      CLICKHOUSE_MERGE_DELAY = 15.seconds

      DEDUP_KEY_COLUMNS = %w[code organization_id external_subscription_id transaction_id timestamp].freeze

      def events(force_from: false, ordered: false)
        Events::Stores::Utils::ClickhouseConnection.with_retry do
          scope = if deduplicate
            events_from = (from_datetime if force_from || use_from_boundary)
            events_to = (applicable_to_datetime if applicable_to_datetime)

            deduplicated_subquery = <<~SQL.squish
              WITH latest_enriched AS (#{latest_enriched_sql(from_datetime: events_from, to_datetime: events_to)})
              #{deduplicated_events_sql(
                from_datetime: events_from,
                to_datetime: events_to,
                deduplicated_columns: %w[value decimal_value properties precise_total_amount_cents]
              )}
            SQL

            ::Clickhouse::EventsEnriched.from("(#{deduplicated_subquery}) AS events_enriched")
          else
            query = ::Clickhouse::EventsEnriched
              .where(external_subscription_id: subscription.external_id)
              .where(organization_id: subscription.organization_id)
              .where(code:)

            query = query.where("events_enriched.timestamp >= ?", from_datetime) if force_from || use_from_boundary
            query = query.where("events_enriched.timestamp <= ?", applicable_to_datetime) if applicable_to_datetime
            query
          end

          scope = scope.order(timestamp: :asc) if ordered
          scope = apply_grouped_by_values(scope) if grouped_by_values?
          filters_scope(scope)
        end
      end

      def events_cte_queries(**args)
        return events_cte_queries_with_deduplication(**args) if deduplicate

        events_cte_queries_without_deduplication(**args)
      end

      def events_cte_queries_without_deduplication(force_from: false, ordered: false, select: arel_table[Arel.star], deduplicated_columns: [])
        query = arel_table.where(
          arel_table[:external_subscription_id].eq(subscription.external_id)
          .and(arel_table[:organization_id].eq(subscription.organization.id)
          .and(arel_table[:code].eq(code)))
        )

        query = query.order(arel_table[:timestamp].desc, arel_table[:value].asc) if ordered

        query = with_timestamp_boundaries(
          query,
          (from_datetime if force_from || use_from_boundary),
          applicable_to_datetime
        )

        query = arel_filters_scope(query)
        query = apply_arel_grouped_by_values(query) if grouped_by_values?

        {"events" => query.project(select).to_sql}
      end

      def events_cte_queries_with_deduplication(force_from: false, ordered: false, select: arel_table[Arel.star], deduplicated_columns: [])
        # Ensure presence of one of value or decimal_value for the ordering
        order_column = deduplicated_columns.include?("decimal_value") ? "decimal_value" : "value"
        deduplicated_columns << order_column if ordered

        events_from = (from_datetime if force_from || use_from_boundary)
        events_to = (applicable_to_datetime if applicable_to_datetime)

        query = arel_table
        query = query.order(arel_table[:timestamp].desc, arel_table[order_column]) if ordered

        query = apply_arel_grouped_by_values(query) if grouped_by_values?
        query = arel_filters_scope(query)

        {
          "latest_enriched" => latest_enriched_sql(from_datetime: events_from, to_datetime: events_to),
          "events_enriched" => deduplicated_events_sql(from_datetime: events_from, to_datetime: events_to, deduplicated_columns:),
          "events" => query.project(select).to_sql
        }
      end

      # ClickHouse cannot guarantee that events_enriched will be deduplicated all the time,
      # so we deduplicate at query time using a two-pass strategy:
      # 1. `latest_enriched_sql` groups events by their dedup key and gets the latest enriched_at.
      # 2. `deduplicated_events_sql` filters `latest_enriched` and uses `INNER ANY JOIN` to
      #    fetch the requested columns from events_enriched. `ANY JOIN` returns at most one
      #    matching row, so duplicated enriched_at are filtered at the join layer
      # This replaces a previous implementation with `argMax` which caused ClickHouse OOM on large subscriptions.
      def latest_enriched_sql(from_datetime:, to_datetime:)
        <<~SQL.squish
          SELECT #{DEDUP_KEY_COLUMNS.join(", ")}, max(enriched_at) AS max_enriched_at
          FROM events_enriched
          WHERE #{deduplicated_events_where_sql(from_datetime:, to_datetime:)}
          GROUP BY #{DEDUP_KEY_COLUMNS.join(", ")}
        SQL
      end

      def deduplicated_events_sql(from_datetime:, to_datetime:, deduplicated_columns: [])
        columns = deduplicated_columns.dup

        # Grouping and filtering is made based on the properties
        if grouped_by.present? || grouped_by_values? || matching_filters.present? || ignored_filters.present?
          columns << "properties"
        end

        picked_columns = columns.uniq.map { "e.#{it}" }
        selected_columns = (DEDUP_KEY_COLUMNS.map { "l.#{it}" } + picked_columns).join(", ")
        join_conditions = (DEDUP_KEY_COLUMNS.map { "e.#{it} = l.#{it}" } + ["e.enriched_at = l.max_enriched_at"]).join(" AND ")

        <<~SQL.squish
          SELECT #{selected_columns}
          FROM latest_enriched AS l
          INNER ANY JOIN events_enriched AS e ON #{join_conditions}
          WHERE #{deduplicated_events_where_sql(from_datetime:, to_datetime:, alias_prefix: "e")}
        SQL
      end

      def deduplicated_events_where_sql(from_datetime:, to_datetime:, alias_prefix: nil)
        prefix = alias_prefix ? "#{alias_prefix}." : ""

        conditions = [
          ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              "#{prefix}organization_id = ? AND #{prefix}code = ? AND #{prefix}external_subscription_id = ?",
              subscription.organization_id,
              code,
              subscription.external_id
            ]
          )
        ]

        conditions << ActiveRecord::Base.sanitize_sql_for_conditions(["#{prefix}timestamp >= ?", from_datetime]) if from_datetime
        conditions << ActiveRecord::Base.sanitize_sql_for_conditions(["#{prefix}timestamp <= ?", to_datetime]) if to_datetime
        conditions.join(" AND ")
      end

      def distinct_charges_and_filters(codes: nil)
        # Implementation relies directly on the events_enriched_expanded table,
        # so we delegate the implementation to the ClickhouseEnrichedStore
        Events::Stores::ClickhouseEnrichedStore.new(
          subscription:,
          boundaries:
        ).distinct_charges_and_filters(codes:)
      end

      # Returns the distinct [code, properties] combinations present in the events of the
      # period. Only properties present in the filter_keys are considered, so the result holds
      # only the dimensions that can be matched against charge filters.
      # An empty hash represents the default (no filter) bucket.
      #
      # ClickHouse stores properties as a Map(String, String); a missing key reads back as an
      # empty string, so blank values are dropped to mirror the Postgres jsonb behaviour.
      def distinct_codes_and_property_combinations(codes:, filter_keys:)
        return [] if codes.empty?

        Events::Stores::Utils::ClickhouseConnection.with_retry do
          scope = ::Clickhouse::EventsEnriched
            .where(external_subscription_id: subscription.external_id)
            .where(organization_id: subscription.organization_id)
            .where(code: codes)
            .where("events_enriched.timestamp >= ?", from_datetime)
            .where("events_enriched.timestamp <= ?", applicable_to_datetime)

          selects = ["DISTINCT code AS code"]
          filter_keys.each_with_index do |key, index|
            selects << ActiveRecord::Base.sanitize_sql_array(["properties[?] AS prop_#{index}", key.to_s])
          end

          scope.select(selects.join(", ")).map do |row|
            combination = {}
            filter_keys.each_with_index do |key, index|
              value = row.read_attribute("prop_#{index}")
              combination[key] = value if value.present?
            end

            [row.code, combination]
          end
        end
      end

      def events_values(limit: nil, force_from: false, exclude_event: false)
        Events::Stores::Utils::ClickhouseConnection.with_retry do
          scope = events(force_from:, ordered: true)

          scope = scope.where("events_enriched.transaction_id != ?", filters[:event].transaction_id) if exclude_event
          scope = scope.limit(limit) if limit

          scope.pluck("events_enriched.decimal_value")
        end
      end

      def last_event
        Events::Stores::Utils::ClickhouseConnection.with_retry { events(ordered: true).last }
      end

      def grouped_last_event
        groups, group_names = grouped_arel_columns

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:decimal_value].as("property"), arel_table[:timestamp]],
            deduplicated_columns: %w[decimal_value]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              DISTINCT ON (#{group_names}) #{group_names},
              events.timestamp,
              property
            FROM events
            ORDER BY #{group_names}, events.timestamp DESC
          SQL

          prepare_grouped_result(connection.select_all(sql).rows, timestamp: true)
        end
      end

      def prorated_events_values(total_duration)
        ratio_sql = duration_ratio_sql(
          "events_enriched.timestamp", to_datetime, total_duration, timezone
        )

        Events::Stores::Utils::ClickhouseConnection.with_retry do
          events(ordered: true).pluck(Arel.sql("events_enriched.decimal_value * (#{ratio_sql})"))
        end
      end

      def count
        value = Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          connection.select_value(count_query).to_i
        end

        build_aggregation_result_from_value(value)
      end

      # Counting deduplicated events only needs the number of distinct dedup keys,
      # not their latest enriched values. We therefore skip the `INNER ANY JOIN`
      # performed by `events_cte_queries` (which materializes a column for every
      # event and roughly doubles the memory of the dedup aggregation) and count
      # the grouped keys directly. This avoids ClickHouse MEMORY_LIMIT_EXCEEDED on
      # very large subscriptions.
      #
      # When the count is filtered (grouped_by_values or matching/ignored filters)
      # we keep the JOIN-based path so the filter still applies to the latest
      # enriched row per dedup key (identical semantics).
      def count_query
        filtered = grouped_by_values? || matching_filters.present? || ignored_filters.present?

        if !deduplicate || filtered
          return with_ctes(events_cte_queries(deduplicated_columns: %w[value]), <<-SQL)
            SELECT count()
            FROM events
          SQL
        end

        events_from = (from_datetime if use_from_boundary)

        <<~SQL.squish
          SELECT count()
          FROM (
            SELECT 1
            FROM events_enriched
            WHERE #{deduplicated_events_where_sql(from_datetime: events_from, to_datetime: applicable_to_datetime)}
            GROUP BY #{DEDUP_KEY_COLUMNS.join(", ")}
          )
        SQL
      end

      def grouped_count(columns = grouped_by)
        groups, column_names = grouped_arel_columns(columns)

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:transaction_id]],
            deduplicated_columns: %w[value properties]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              #{column_names},
              toDecimal32(count(), 0)
            FROM events
            GROUP BY #{column_names}
          SQL

          grouped_results_with_value_as_count(prepare_grouped_result(connection.select_all(sql).rows, columns: columns))
        end
      end

      # NOTE: check if an event created before the current on belongs to an active (as in present and not removed)
      #       unique property
      def active_unique_property?(event)
        previous_event = Events::Stores::Utils::ClickhouseConnection.with_retry do
          events
            .where("events_enriched.properties[?] = ?", aggregation_property, event.properties[aggregation_property])
            .where("events_enriched.timestamp < ?", event.timestamp)
            .order(timestamp: :desc)
            .first
        end

        previous_event && (
          previous_event.properties["operation_type"].nil? ||
          previous_event.properties["operation_type"] == "add"
        )
      end

      def unique_count
        result = Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: self)
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.query),
              {decimal_date_scale: DECIMAL_DATE_SCALE}
            ]
          )
          connection.select_one(sql)
        end

        build_aggregation_result_from_value(result["aggregation"])
      end

      # NOTE: not used in production, only for debug purpose to check the computed values before aggregation
      def unique_count_breakdown
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: self)

          connection.select_all(
            ActiveRecord::Base.sanitize_sql_for_conditions(
              [
                sanitize_colon(query.breakdown_query),
                {decimal_date_scale: DECIMAL_DATE_SCALE}
              ]
            )
          ).rows
        end
      end

      def prorated_unique_count
        result = Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: self)
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.prorated_query),
              {
                from_datetime:,
                to_datetime:,
                decimal_date_scale: DECIMAL_DATE_SCALE,
                timezone: customer.applicable_timezone
              }
            ]
          )
          connection.select_one(sql)
        end

        build_aggregation_result_from_value(result["aggregation"])
      end

      def prorated_unique_count_breakdown(with_remove: false)
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: self)
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.prorated_breakdown_query(with_remove:)),
              {
                from_datetime:,
                to_datetime:,
                decimal_date_scale: DECIMAL_DATE_SCALE,
                timezone: customer.applicable_timezone
              }
            ]
          )

          connection.select_all(sql).to_a
        end
      end

      def grouped_unique_count(columns = grouped_by)
        duplicated_unique_count_store = dup
        duplicated_unique_count_store.grouped_by = columns

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: duplicated_unique_count_store)
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.grouped_query),
              {
                to_datetime:,
                decimal_date_scale: DECIMAL_DATE_SCALE
              }
            ]
          )

          grouped_results_with_value_as_count(
            prepare_grouped_result(connection.select_all(sql).rows, columns: columns)
          )
        end
      end

      def grouped_prorated_unique_count
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::UniqueCountQuery.new(store: self)
          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.grouped_prorated_query),
              {
                from_datetime:,
                to_datetime:,
                decimal_date_scale: DECIMAL_DATE_SCALE,
                timezone: customer.applicable_timezone
              }
            ]
          )
          grouped_results_with_value_as_count(
            prepare_grouped_result(connection.select_all(sql).rows)
          )
        end
      end

      def max(with_count: true)
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value]), <<-SQL)
            SELECT
              max(events.decimal_value) as value,
              #{with_count ? "count()" : "null"} as events_count
            FROM events
          SQL

          build_aggregation_result(connection.select_one(sql))
        end
      end

      def grouped_max(columns = grouped_by, with_count: true)
        groups, column_names = grouped_arel_columns(columns)

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:decimal_value].as("property"), arel_table[:timestamp]],
            deduplicated_columns: %w[decimal_value properties]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              #{column_names},
              MAX(property),
              #{with_count ? "count()" : "null"}
            FROM events
            GROUP BY #{column_names}
          SQL

          prepare_grouped_aggregated_values(connection.select_all(sql).rows, columns: columns)
        end
      end

      def last(with_count: true)
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: [arel_table[:decimal_value].as("property"), arel_table[:timestamp]],
            deduplicated_columns: %w[decimal_value properties]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              property as value,
              #{with_count ? "count() OVER ()" : "null"} as events_count
            FROM events
            ORDER BY events.timestamp DESC
            LIMIT 1
          SQL

          build_last_aggregation_result(connection.select_one(sql), with_count:)
        end
      end

      def grouped_last(columns = grouped_by, with_count: true)
        groups, column_names = grouped_arel_columns(columns)
        distinct_on_names = grouped_by.present? ? grouped_arel_columns.last : nil

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:decimal_value].as("property"), arel_table[:timestamp]],
            deduplicated_columns: %w[decimal_value properties]
          )

          sql = if distinct_on_names
            count_select = with_count ? "count() OVER (PARTITION BY #{distinct_on_names})" : "null"
            with_ctes(ctes_sql, <<-SQL)
              SELECT
                DISTINCT ON (#{distinct_on_names}) #{column_names},
                property,
                #{count_select} as events_count
              FROM events
              ORDER BY #{distinct_on_names}, events.timestamp DESC
            SQL
          else
            count_select = with_count ? "count() OVER ()" : "null"
            with_ctes(ctes_sql, <<-SQL)
              SELECT
                #{column_names},
                property,
                #{count_select} as events_count
              FROM events
              ORDER BY events.timestamp DESC
              LIMIT 1
            SQL
          end

          prepare_grouped_aggregated_values(connection.select_all(sql).rows, columns: columns)
        end
      end

      def sum_precise_total_amount_cents
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[precise_total_amount_cents]), <<-SQL)
            SELECT COALESCE(SUM(events.precise_total_amount_cents), 0)
            FROM events
          SQL

          connection.select_value(sql)
        end
      end

      def grouped_sum_precise_total_amount_cents
        groups, group_names = grouped_arel_columns

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:precise_total_amount_cents].as("precise_total_amount_cents")],
            deduplicated_columns: %w[precise_total_amount_cents]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              #{group_names},
              sum(events.precise_total_amount_cents)
            FROM events
            GROUP BY #{group_names}
          SQL

          prepare_grouped_result(connection.select_all(sql).rows)
        end
      end

      def sum(with_count: true)
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value]), <<-SQL)
            SELECT
              sum(events.decimal_value) as value,
              #{with_count ? "count()" : "null"} as events_count
            FROM events
          SQL

          build_aggregation_result(connection.select_one(sql))
        end
      end

      def grouped_sum(columns = grouped_by, with_count: true)
        groups, column_names = grouped_arel_columns(columns)

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [arel_table[:decimal_value].as("property")],
            deduplicated_columns: %w[decimal_value properties]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              #{column_names},
              sum(events.property),
              #{with_count ? "count()" : "null"}
            FROM events
            GROUP BY #{column_names}
          SQL

          prepare_grouped_aggregated_values(connection.select_all(sql).rows, columns: columns)
        end
      end

      def prorated_sum(period_duration:, persisted_duration: nil)
        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql(
            "events_enriched.timestamp", to_datetime, period_duration, timezone
          )
        end

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: [
              arel_table[:decimal_value],
              Arel::Nodes::InfixOperation.new(
                "*",
                arel_table[:decimal_value],
                Arel::Nodes::Grouping.new(Arel::Nodes::SqlLiteral.new(ratio.to_s))
              ).as("prorated_value")
            ],
            deduplicated_columns: %w[decimal_value]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              sum(events.prorated_value) as prorated_value,
              sum(events.decimal_value) as value,
              count() as events_count
            FROM events
          SQL

          build_prorated_aggregation_result(connection.select_one(sql))
        end
      end

      def grouped_prorated_sum(period_duration:, persisted_duration: nil)
        groups, group_names = grouped_arel_columns

        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql("events_enriched.timestamp", to_datetime, period_duration, timezone)
        end

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: groups + [
              arel_table[:decimal_value],
              Arel::Nodes::InfixOperation.new(
                "*",
                arel_table[:decimal_value],
                Arel::Nodes::Grouping.new(Arel::Nodes::SqlLiteral.new(ratio.to_s))
              ).as("prorated_value")
            ],
            deduplicated_columns: %w[decimal_value]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              #{group_names},
              sum(events.prorated_value) as prorated_value,
              sum(events.decimal_value) as value,
              count() as events_count
            FROM events
            GROUP BY #{group_names}
          SQL

          prepare_grouped_prorated_result(connection.select_all(sql).rows)
        end
      end

      def sum_date_breakdown
        date_field = date_in_customer_timezone_sql("events_enriched.timestamp", timezone)

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: [
              Arel::Nodes::NamedFunction.new(
                "toDate",
                [Arel::Nodes::SqlLiteral.new(date_field)]
              ).as("day"),
              arel_table[:decimal_value].as("property")
            ],
            deduplicated_columns: %w[decimal_value]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              events.day,
              sum(events.property) AS day_sum
            FROM events
            GROUP BY events.day
            ORDER BY events.day asc
          SQL

          connection.select_all(Arel.sql(sql)).rows.map do |row|
            {date: row.first.to_date, value: row.last}
          end
        end
      end

      def weighted_sum(initial_value: 0)
        result = Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::WeightedSumQuery.new(store: self)

          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.query),
              {
                from_datetime:,
                to_datetime: to_datetime.ceil,
                decimal_scale: DECIMAL_SCALE,
                initial_value: decimal_literal(initial_value || 0)
              }
            ]
          )

          connection.select_one(sql)
        end

        build_weighted_aggregation_result(
          value: BigDecimal(result["aggregation"].presence || 0),
          variation_with_initial: BigDecimal(result["variation_with_initial"].presence || 0),
          rows_count: result["rows_count"].to_i,
          initial_value:
        )
      end

      def grouped_weighted_sum(columns = grouped_by, initial_value: 0, initial_values: [])
        duplicated_weighted_sum_store = dup
        duplicated_weighted_sum_store.grouped_by = columns

        baseline_initial_values = if initial_values.present?
          initial_values
        elsif initial_value.to_d.nonzero?
          [{groups: {}, value: initial_value}]
        else
          []
        end

        formatted_initial_values = duplicated_weighted_sum_store.formatted_weighted_sum_initial_values(baseline_initial_values)
        return [] if formatted_initial_values.empty?

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Clickhouse::WeightedSumQuery.new(store: duplicated_weighted_sum_store)

          sql = ActiveRecord::Base.sanitize_sql_for_conditions(
            [
              sanitize_colon(query.grouped_query(initial_values: formatted_initial_values)),
              {
                from_datetime:,
                to_datetime: to_datetime.ceil,
                decimal_scale: DECIMAL_SCALE
              }
            ]
          )

          prepare_grouped_weighted_values(connection.select_all(sql).rows, formatted_initial_values, columns: columns)
        end
      end

      # NOTE: not used in production, only for debug purpose to check the computed values before aggregation
      def weighted_sum_breakdown(initial_value: 0)
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Events::Stores::Clickhouse::WeightedSumQuery.new(store: self)

          rows = connection.select_all(
            ActiveRecord::Base.sanitize_sql_for_conditions(
              [
                sanitize_colon(query.breakdown_query),
                {
                  from_datetime:,
                  to_datetime: to_datetime.ceil,
                  decimal_scale: DECIMAL_SCALE,
                  initial_value: decimal_literal(initial_value || 0)
                }
              ]
            )
          ).rows
          # `date_diff` actually returns an `Int64` and ActiveRecord transform that into a `String`. If we cast the
          # result in a `Int32`, then we get the result as `Integer`:
          # ```ruby
          # lago-api(staging)> Clickhouse::BaseRecord.connection.select_one("SELECT 1::Int64")
          # => {"CAST('1', 'Int64')" => "1"}
          # lago-api(staging)> Clickhouse::BaseRecord.connection.select_one("SELECT 1::Int32")
          # => {"CAST('1', 'Int32')" => 1}
          # ```
          # To keep consistency with the PG implementation, we call `#to_i` on the value.
          rows.map do |(timestamp, difference, cumul, second_duration, period_ratio)|
            [timestamp, difference, cumul, second_duration.to_i, period_ratio]
          end
        end
      end

      def with_timestamp_boundaries(query, from_datetime, to_datetime)
        query = query.where(arel_table[:timestamp].gteq(from_datetime)) if from_datetime
        query = query.where(arel_table[:timestamp].lteq(to_datetime)) if to_datetime
        query
      end

      def filters_scope(scope)
        matching_filters.each do |key, values|
          scope = scope.where("events_enriched.properties[?] IN (?)", key.to_s, values)
        end

        conditions = ignored_filters.filter_map do |filters|
          next if filters.empty?

          clause = filters.filter_map do |key, values|
            next if values.empty?

            ActiveRecord::Base.sanitize_sql_for_conditions(
              ["(coalesce(events_enriched.properties[?], '') IN (?))", key.to_s, values.map(&:to_s)]
            )
          end.join(" AND ")
          clause.presence
        end
        sql = conditions.map { "(#{it})" }.join(" OR ")
        scope = scope.where.not(sql) if sql.present?

        scope
      end

      def arel_filters_scope(scope)
        matching_filters.each do |key, values|
          scope = scope.where(
            Arel::Nodes::SqlLiteral.new(sanitized_property_name(key.to_s)).in(values.map(&:to_s))
          )
        end

        conditions = ignored_filters.filter_map do |filters|
          next if filters.empty?

          clause = filters.filter_map do |key, values|
            next if values.empty?

            ActiveRecord::Base.sanitize_sql_for_conditions(
              ["(coalesce(events_enriched.properties[?], '') IN (?))", key.to_s, values.map(&:to_s)]
            )
          end.join(" AND ")
          clause.presence
        end
        sql = conditions.map { "(#{it})" }.join(" OR ")
        scope = scope.where(Arel::Nodes::Not.new(Arel::Nodes::SqlLiteral.new(sql))) if conditions.present?

        scope
      end

      def apply_grouped_by_values(scope)
        grouped_by_values.each do |grouped_by, grouped_by_value|
          scope = if grouped_by_value.present?
            scope.where("events_enriched.properties[?] = ?", grouped_by, grouped_by_value)
          else
            scope.where("COALESCE(events_enriched.properties[?], '') = ''", grouped_by)
          end
        end

        scope
      end

      def apply_arel_grouped_by_values(query)
        grouped_by_values.each do |grouped_by, grouped_by_value|
          query = if grouped_by_value.present?
            query.where(Arel::Nodes::SqlLiteral.new(sanitized_property_name(grouped_by)).eq(grouped_by_value))
          else
            query.where(
              Arel::Nodes::NamedFunction.new(
                "COALESCE",
                [
                  Arel::Nodes::SqlLiteral.new(sanitized_property_name(grouped_by)),
                  Arel::Nodes::SqlLiteral.new("''")
                ]
              ).eq(Arel::Nodes::SqlLiteral.new("''"))
            )
          end
        end

        query
      end

      def sanitized_property_name(property = aggregation_property)
        ActiveRecord::Base.sanitize_sql_for_conditions(
          ["events_enriched.properties[?]", property]
        )
      end

      # NOTE: returns the values for each groups
      #       The result format will be an array of hash with the format:
      #       [{ groups: { 'cloud' => 'aws', 'region' => 'us_east_1' }, value: 12.9 }, ...]
      def prepare_grouped_result(rows, timestamp: false, decimal: false, columns: grouped_by)
        rows.map do |row|
          last_group = timestamp ? -2 : -1

          result = {
            groups: build_groups(row.flatten[...last_group], columns:),
            value: decimal ? BigDecimal(row.last.presence || 0) : row.last
          }

          result[:timestamp] = row[-2] if timestamp

          result
        end
      end

      # NOTE: Same as prepare_grouped_result but the last two columns of each row are
      #       the aggregated value and the events count, returned as GroupedAggregationResult.
      def prepare_grouped_aggregated_values(rows, columns: grouped_by)
        rows.map do |row|
          flat = row.flatten

          GroupedAggregationResult.new(
            groups: build_groups(flat[...-2], columns:),
            value: flat[-2],
            events_count: flat[-1].presence&.to_i
          )
        end
      end

      # NOTE: Same as prepare_grouped_aggregated_values but the last three columns of each
      #       row are the prorated value, the non-prorated value and the events count,
      #       returned as GroupedProratedAggregationResult.
      def prepare_grouped_prorated_result(rows, columns: grouped_by)
        rows.map do |row|
          flat = row.flatten

          build_grouped_prorated_aggregation_result(
            groups: build_groups(flat[...-3], columns:),
            prorated_value: flat[-3],
            value: flat[-2],
            events_count: flat[-1]
          )
        end
      end

      # NOTE: parses the grouped weighted_sum rows. The last three columns of each row are the weighted
      #       aggregation, the sum of the differences (including the initial value) and the rows count
      #       (including the 2 boundary rows). Correction is delegated to build_grouped_weighted_result.
      def prepare_grouped_weighted_values(rows, initial_values, columns: grouped_by)
        rows.map do |row|
          flat = row.flatten

          build_grouped_weighted_result(
            groups: build_groups(flat[...-3], columns:),
            value: BigDecimal(flat[-3].presence || 0),
            variation_with_initial: BigDecimal(flat[-2].presence || 0),
            rows_count: flat[-1].to_i,
            initial_values:
          )
        end
      end

      def arel_table
        @arel_table ||= ::Clickhouse::EventsEnriched.arel_table
      end

      def grouped_arel_columns(columns = grouped_by)
        names = Array.new(columns.count) { |i| "g_#{i}" }
        [
          columns.map.with_index { |col, i| Arel::Nodes::SqlLiteral.new(sanitized_property_name(col)).as("g_#{i}") },
          names.join(", ")
        ]
      end

      def grouped_by_columns(values)
        grouped_by.map { |g| quote(values[g] || "") }
      end

      delegate :count, to: :grouped_by, prefix: true

      def operation_type_sql
        "events_enriched.sorted_properties['operation_type']"
      end

      def formatted_weighted_sum_initial_values(initial_values)
        formatted_initial_values = grouped_count.map do |group|
          value = 0
          previous_group = initial_values.find { |g| g[:groups] == group.groups }
          value = previous_group[:value] if previous_group
          {groups: group.groups, value:}
        end

        initial_values.each do |initial_value|
          next if formatted_initial_values.find { |g| g[:groups] == initial_value[:groups] }

          formatted_initial_values << initial_value
        end

        formatted_initial_values
      end
    end
  end
end
