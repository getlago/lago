# frozen_string_literal: true

module Events
  module Stores
    class ClickhouseEnrichedStore < BaseStore
      include Events::Stores::Utils::QueryHelpers
      include Events::Stores::Utils::ClickhouseSqlHelpers

      DEDUP_KEY_COLUMNS = %w[charge_id charge_filter_id external_subscription_id organization_id timestamp transaction_id].freeze
      DEDUP_FALLBACK_KEY_COLUMNS = %w[external_subscription_id organization_id timestamp transaction_id].freeze

      def events(force_from: false, ordered: false)
        Events::Stores::Utils::ClickhouseConnection.with_retry do
          order_clause = ordered ? "ORDER BY timestamp ASC" : ""

          sql = with_ctes(
            events_cte_queries(
              deduplicated_columns: %w[decimal_value value properties precise_total_amount_cents code external_subscription_id],
              force_from:
            ),
            <<-SQL
              SELECT *
              FROM events
              #{order_clause}
            SQL
          )

          ::Clickhouse::EventsEnrichedExpanded.find_by_sql(sql)
        end
      end

      def events_cte_queries(**args)
        return events_cte_queries_with_deduplication(**args) if deduplicate

        events_cte_queries_without_deduplication(**args)
      end

      def events_cte_queries_without_deduplication(force_from: false, ordered: false, select: arel_table[Arel.star], deduplicated_columns: [], to_datetime: nil)
        effective_to = to_datetime || applicable_to_datetime

        if needs_code_based_fallback?(force_from:)
          current_query = charge_id_based_query(from_datetime: subscription.started_at, to_datetime: effective_to)
          fallback_query = code_based_fallback_query(from_datetime: (from_datetime if force_from))

          current_sql = current_query.project(select).to_sql
          fallback_sql = fallback_query.project(select).to_sql + " ORDER BY enriched_at DESC LIMIT 1 BY transaction_id, timestamp"

          return {"events" => "(#{current_sql}) UNION ALL (#{fallback_sql})"}
        end

        query = charge_id_based_query(
          from_datetime: (from_datetime if force_from || use_from_boundary),
          to_datetime: effective_to
        )
        query = query.order(arel_table[:timestamp].desc, arel_table[:value].asc) if ordered

        {"events" => query.project(select).to_sql}
      end

      def events_cte_queries_with_deduplication(force_from: false, ordered: false, select: arel_table[Arel.star], deduplicated_columns: [], to_datetime: nil)
        # Ensure presence of one of value or decimal_value for the ordering
        order_column = deduplicated_columns.include?("decimal_value") ? "decimal_value" : "value"
        deduplicated_columns << order_column if ordered

        effective_to = to_datetime.presence || applicable_to_datetime.presence

        # Should we include recurring events from previous subscription by relying on the code instead of the charge_id
        use_fallback = needs_code_based_fallback?(force_from:)
        current_from = use_fallback ? subscription.started_at : (from_datetime if force_from || use_from_boundary)

        ctes = {
          "latest_enriched_current" => latest_enriched_current_sql(from_datetime: current_from, to_datetime: effective_to)
        }
        second_passes = [deduplicated_events_sql(from_datetime: current_from, to_datetime: effective_to, deduplicated_columns:)]

        if use_fallback
          fallback_from = (from_datetime if force_from)
          ctes["latest_enriched_fallback"] = latest_enriched_fallback_sql(from_datetime: fallback_from)
          second_passes << code_based_fallback_dedup_sql(from_datetime: fallback_from, deduplicated_columns:)
        end

        ctes["events_enriched_expanded"] = (second_passes.size == 1) ? second_passes.first : second_passes.map { "(#{it})" }.join(" UNION ALL ")

        query = Arel::Table.new(:events_enriched_expanded)
        query = query.order(arel_table[:timestamp].desc, arel_table[order_column.to_sym]) if ordered

        ctes["events"] = query.project(select).to_sql
        ctes
      end

      # ClickHouse cannot guarantee that events_enriched_expanded will be deduplicated all the time,
      # so we deduplicate at query time using a two-pass strategy:
      # 1. `latest_enriched_current_sql` groups events by their dedup key and gets the latest enriched_at.
      # 2. `deduplicated_events_sql` filters `latest_enriched_current` and uses `INNER ANY JOIN` to
      #    fetch the requested columns from events_enriched_expanded. `ANY JOIN` returns at most one
      #    matching row, so duplicated enriched_at are filtered at the join layer.
      # This replaces a previous implementation with `argMax` which caused ClickHouse OOM on large subscriptions.
      def latest_enriched_current_sql(from_datetime:, to_datetime:)
        <<~SQL.squish
          SELECT #{DEDUP_KEY_COLUMNS.join(", ")}, max(enriched_at) AS max_enriched_at
          FROM events_enriched_expanded
          WHERE #{charge_id_based_where_sql(from_datetime:, to_datetime:, include_grouped_by_values: false)}
          GROUP BY #{DEDUP_KEY_COLUMNS.join(", ")}
        SQL
      end

      def deduplicated_events_sql(from_datetime:, to_datetime:, deduplicated_columns: [])
        extra_columns = dedup_selected_columns(deduplicated_columns)
        selected_columns = (DEDUP_KEY_COLUMNS.map { "l.#{it}" } + extra_columns).join(", ")
        join_conditions = (DEDUP_KEY_COLUMNS.map { "e.#{it} = l.#{it}" } + ["e.enriched_at = l.max_enriched_at"]).join(" AND ")

        <<~SQL.squish
          SELECT #{selected_columns}
          FROM latest_enriched_current AS l
          INNER ANY JOIN events_enriched_expanded AS e ON #{join_conditions}
          WHERE #{charge_id_based_where_sql(from_datetime:, to_datetime:, alias_prefix: "e")}
        SQL
      end

      # Code-based fallback for recurring charges.
      # First pass: groups events on the smaller dedup key (no charge_id/charge_filter_id)
      # because fallback events come from a previous subscription's charges, so charge_ids are irrelevant.
      # Matching/ignored filters and grouped_by_values are deferred to the second pass to keep
      # the dedup grouping based on the base columns only (org, code, subscription, timestamp, transaction).
      def latest_enriched_fallback_sql(from_datetime:)
        <<~SQL.squish
          SELECT #{DEDUP_FALLBACK_KEY_COLUMNS.join(", ")}, max(enriched_at) AS max_enriched_at
          FROM events_enriched_expanded
          WHERE #{code_based_fallback_where_sql(from_datetime:, include_grouped_by_values: false, include_filters: false)}
          GROUP BY #{DEDUP_FALLBACK_KEY_COLUMNS.join(", ")}
        SQL
      end

      # Code-based fallback second pass for events before subscription.started_at.
      # Projects dummy charge_id/charge_filter_id for UNION compatibility with deduplicated_events_sql.
      def code_based_fallback_dedup_sql(from_datetime:, deduplicated_columns: [])
        extra_columns = dedup_selected_columns(deduplicated_columns)
        selected_columns = (
          ["'' AS charge_id", "'' AS charge_filter_id"] +
          DEDUP_FALLBACK_KEY_COLUMNS.map { "l.#{it}" } +
          extra_columns
        ).join(", ")
        join_conditions = (DEDUP_FALLBACK_KEY_COLUMNS.map { "e.#{it} = l.#{it}" } + ["e.enriched_at = l.max_enriched_at"]).join(" AND ")

        <<~SQL.squish
          SELECT #{selected_columns}
          FROM latest_enriched_fallback AS l
          INNER ANY JOIN events_enriched_expanded AS e ON #{join_conditions}
          WHERE #{code_based_fallback_where_sql(from_datetime:, alias_prefix: "e")}
        SQL
      end

      def distinct_charges_and_filters(codes: nil)
        Events::Stores::Utils::ClickhouseConnection.with_retry do
          scope = ::Clickhouse::EventsEnrichedExpanded
            .where(external_subscription_id: subscription.external_id)
            .where(organization_id: subscription.organization_id)
            .where(timestamp: from_datetime..to_datetime)

          scope = scope.where(code: codes) unless codes.nil?
          scope.distinct.pluck("charge_id", Arel.sql("nullIf(charge_filter_id, '')"))
        end
      end

      def events_values(limit: nil, force_from: false, exclude_event: false)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          table = Arel::Table.new("events")
          query = table.order(table[:timestamp].asc)

          if exclude_event
            query = query.where(table[:transaction_id].not_eq(filters[:event].transaction_id))
          end

          query = query.take(limit) if limit

          sql = with_ctes(events_cte_queries(
            deduplicated_columns: %w[decimal_value],
            force_from:
          ), query.project(table[:decimal_value]).to_sql)

          connection.select_values(sql)
        end
      end

      def prorated_events_values(total_duration)
        ratio = duration_ratio_sql(
          "events_enriched_expanded.timestamp", to_datetime, total_duration, timezone
        )

        Utils::ClickhouseConnection.connection_with_retry do |connection|
          table = Arel::Table.new("events")
          query = table.order(table[:timestamp].asc)

          sql = with_ctes(events_cte_queries(
            select: [
              arel_table[:timestamp],
              Arel::Nodes::InfixOperation.new(
                "*",
                arel_table[:decimal_value],
                Arel::Nodes::Grouping.new(Arel::Nodes::SqlLiteral.new(ratio.to_s))
              ).as("prorated_value")
            ],
            deduplicated_columns: %w[decimal_value]
          ), query.project(table[:prorated_value]).to_sql)

          connection.select_values(sql)
        end
      end

      def last_event
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value properties]), <<-SQL)
            SELECT *
            FROM events
            ORDER BY timestamp DESC
            LIMIT 1
          SQL

          attributes = connection.select_one(sql)
          break if attributes.nil?

          ::Clickhouse::EventsEnrichedExpanded.new(attributes)
        end
      end

      def grouped_last_event
        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: [arel_table[:sorted_grouped_by], arel_table[:decimal_value].as("property"), arel_table[:timestamp]],
            deduplicated_columns: %w[decimal_value]
          )

          sql = with_ctes(ctes_sql, <<-SQL)
            SELECT
              DISTINCT ON (sorted_grouped_by) sorted_grouped_by as groups,
              events.timestamp,
              property as value
            FROM events
            ORDER BY sorted_grouped_by, timestamp DESC
          SQL

          prepare_grouped_result(connection.select_all(sql))
        end
      end

      def count
        value = Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[value]), <<-SQL)
            SELECT count()
            FROM events
          SQL

          connection.select_value(sql).to_i
        end

        build_aggregation_result_from_value(value)
      end

      def grouped_count(columns = grouped_by)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          if columns == grouped_by
            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[value], select: [arel_table[:sorted_grouped_by]]), <<-SQL)
              SELECT
                sorted_grouped_by as groups,
                toDecimal32(count(), 0) as value
              FROM events
              GROUP BY sorted_grouped_by
            SQL
          else
            map_args, col_expressions = sorted_properties_map_args(columns)

            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[value sorted_properties]), <<-SQL)
              SELECT
                map(#{map_args.join(", ")}) as groups,
                toDecimal32(count(), 0) as value
              FROM events
              GROUP BY #{col_expressions.join(", ")}
            SQL
          end

          grouped_results_with_value_as_count(prepare_grouped_result(connection.select_all(sql)))
        end
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
            prepare_grouped_result(connection.select_all(sql), groups_key: :grouped_by, value_key: :aggregation)
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
            prepare_grouped_result(connection.select_all(sql), groups_key: :grouped_by, value_key: :aggregation)
          )
        end
      end

      def active_unique_property?(event)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(
            deduplicated_columns: %w[value properties],
            to_datetime: event.timestamp - 0.001.seconds,
            ordered: true
          ), <<-SQL)
            SELECT properties
            FROM events
            WHERE value = ?
            ORDER BY timestamp DESC
            LIMIT 1
          SQL

          previous_properties = connection.select_one(
            ActiveRecord::Base.sanitize_sql_for_conditions([sql, event.properties[aggregation_property].to_s])
          )
          return false if previous_properties.nil?

          operation_type = previous_properties.dig("properties", "operation_type")
          operation_type.nil? || operation_type == "add"
        end
      end

      def max(with_count: true)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
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
        count_select = with_count ? "count()" : "null"

        Utils::ClickhouseConnection.connection_with_retry do |connection|
          if columns == grouped_by
            sql = with_ctes(events_cte_queries(
              deduplicated_columns: %w[decimal_value],
              select: [arel_table[:sorted_grouped_by], arel_table[:decimal_value]]
            ), <<-SQL)
              SELECT
                sorted_grouped_by as groups,
                MAX(events.decimal_value) as value,
                #{count_select} as events_count
              FROM events
              GROUP BY sorted_grouped_by
            SQL
          else
            map_args, col_expressions = sorted_properties_map_args(columns)

            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value sorted_properties]), <<-SQL)
              SELECT
                map(#{map_args.join(", ")}) as groups,
                MAX(events.decimal_value) as value,
                #{count_select} as events_count
              FROM events
              GROUP BY #{col_expressions.join(", ")}
            SQL
          end

          prepare_grouped_aggregated_values(connection.select_all(sql))
        end
      end

      def last(with_count: true)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value]), <<-SQL)
            SELECT
              decimal_value as value,
              #{with_count ? "count() OVER ()" : "null"} as events_count
            FROM events
            ORDER BY timestamp DESC
            LIMIT 1
          SQL

          build_last_aggregation_result(connection.select_one(sql), with_count:)
        end
      end

      def grouped_last(columns = grouped_by, with_count: true)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          if columns == grouped_by
            count_select = with_count ? "count() OVER (PARTITION BY sorted_grouped_by)" : "null"
            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value]), <<-SQL)
              SELECT
                DISTINCT ON (sorted_grouped_by) sorted_grouped_by as groups,
                events.decimal_value as value,
                #{count_select} as events_count
              FROM events
              ORDER BY sorted_grouped_by, timestamp DESC
            SQL
          else
            map_args, = sorted_properties_map_args(columns)

            sql = if grouped_by.blank?
              count_select = with_count ? "count() OVER ()" : "null"
              with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value sorted_properties]), <<-SQL)
                SELECT
                  map(#{map_args.join(", ")}) as groups,
                  events.decimal_value as value,
                  #{count_select} as events_count
                FROM events
                ORDER BY timestamp DESC
                LIMIT 1
              SQL
            else
              count_select = with_count ? "count() OVER (PARTITION BY sorted_grouped_by)" : "null"
              with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value sorted_properties]), <<-SQL)
                SELECT
                  DISTINCT ON (sorted_grouped_by) map(#{map_args.join(", ")}) as groups,
                  events.decimal_value as value,
                  #{count_select} as events_count
                FROM events
                ORDER BY sorted_grouped_by, timestamp DESC
              SQL
            end
          end

          prepare_grouped_aggregated_values(connection.select_all(sql))
        end
      end

      def sum(with_count: true)
        Utils::ClickhouseConnection.connection_with_retry do |connection|
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
        count_select = with_count ? "count()" : "null"

        Utils::ClickhouseConnection.connection_with_retry do |connection|
          if columns == grouped_by
            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value]), <<-SQL)
              SELECT
                sorted_grouped_by as groups,
                sum(events.decimal_value) as value,
                #{count_select} as events_count
              FROM events
              GROUP BY sorted_grouped_by
            SQL
          else
            map_args, col_expressions = sorted_properties_map_args(columns)

            sql = with_ctes(events_cte_queries(deduplicated_columns: %w[decimal_value sorted_properties]), <<-SQL)
              SELECT
                map(#{map_args.join(", ")}) as groups,
                sum(events.decimal_value) as value,
                #{count_select} as events_count
              FROM events
              GROUP BY #{col_expressions.join(", ")}
            SQL
          end

          prepare_grouped_aggregated_values(connection.select_all(sql))
        end
      end

      def sum_precise_total_amount_cents
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[precise_total_amount_cents]), <<-SQL)
            SELECT COALESCE(sum(events.precise_total_amount_cents), 0)
            FROM events
          SQL

          connection.select_value(sql)
        end
      end

      def grouped_sum_precise_total_amount_cents
        Utils::ClickhouseConnection.connection_with_retry do |connection|
          sql = with_ctes(events_cte_queries(deduplicated_columns: %w[precise_total_amount_cents]), <<-SQL)
            SELECT
              sorted_grouped_by as groups,
              sum(events.precise_total_amount_cents) as value
            FROM events
            GROUP BY sorted_grouped_by
          SQL

          prepare_grouped_result(connection.select_all(sql))
        end
      end

      def prorated_sum(period_duration:, persisted_duration: nil)
        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql(
            "events_enriched_expanded.timestamp", to_datetime, period_duration, timezone
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
        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql(
            "events_enriched_expanded.timestamp", to_datetime, period_duration, timezone
          )
        end

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          ctes_sql = events_cte_queries(
            select: [arel_table[:sorted_grouped_by]] + [
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
              sorted_grouped_by as groups,
              sum(events.prorated_value) as prorated_value,
              sum(events.decimal_value) as value,
              count() as events_count
            FROM events
            GROUP BY sorted_grouped_by
          SQL

          prepare_grouped_prorated_values(connection.select_all(sql))
        end
      end

      def sum_date_breakdown
        date_field = date_in_customer_timezone_sql("events_enriched_expanded.timestamp", timezone)

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

      def grouped_weighted_sum(columns = grouped_by, initial_values: [])
        duplicated_weighted_sum_store = dup
        duplicated_weighted_sum_store.grouped_by = columns

        Events::Stores::Utils::ClickhouseConnection.connection_with_retry do |connection|
          query = Clickhouse::WeightedSumQuery.new(store: duplicated_weighted_sum_store)

          # NOTE: build the list of initial values for each groups
          #       from the events in the period
          formatted_initial_values = grouped_count(columns).map do |group|
            value = 0
            previous_group = initial_values.find { |g| g[:groups] == group.groups }
            value = previous_group[:value] if previous_group
            {groups: group.groups, value:}
          end

          # NOTE: add the initial values for groups that are not in the events
          initial_values.each do |initial_value|
            next if formatted_initial_values.find { |g| g[:groups] == initial_value[:groups] }

            formatted_initial_values << initial_value
          end
          return [] if formatted_initial_values.empty?

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

          prepare_grouped_weighted_values(connection.select_all(sql), formatted_initial_values)
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

      def arel_table
        @arel_table ||= ::Clickhouse::EventsEnrichedExpanded.arel_table
      end

      def grouped_arel_columns
        return [[arel_table[:sorted_grouped_by].as("grouped_by")], group_names] unless with_presentation_by_in_grouped_by?

        map_args, = sorted_properties_map_args(grouped_by, table: nil)
        map_sql = map_args.join(", ")

        grouped_by_node = Arel::Nodes::As.new(
          Arel::Nodes::SqlLiteral.new("map(#{map_sql})"),
          Arel::Nodes::SqlLiteral.new("grouped_by")
        )

        [[grouped_by_node], ["grouped_by"]]
      end

      def group_names
        [joined_group_names]
      end

      def joined_group_names
        "grouped_by"
      end

      def grouped_by_columns(values)
        map_values = values.map { |g, v| [quote(g), quote(v || "")] }
        "map(#{map_values.flatten.join(", ")})"
      end

      def grouped_by_count
        1
      end

      def sorted_properties_map_args(columns, table: "events")
        prefix = table ? "#{table}." : ""

        map_args = columns.sort.flat_map do |col|
          [
            ActiveRecord::Base.sanitize_sql_for_conditions(["?", col.to_s]),
            ActiveRecord::Base.sanitize_sql_for_conditions(["#{prefix}sorted_properties[?]", col.to_s])
          ]
        end

        [map_args, map_args.each_slice(2).map(&:last)]
      end

      def operation_type_sql
        "events_enriched_expanded.sorted_properties['operation_type']"
      end

      def dedup_selected_columns(deduplicated_columns)
        columns = deduplicated_columns.dup
        columns << "sorted_grouped_by" if grouped_by.present? || grouped_by_values.present?

        columns.uniq.reject { DEDUP_KEY_COLUMNS.include?(it) }.map { "e.#{it}" }
      end

      def charge_id_based_where_sql(from_datetime:, to_datetime:, alias_prefix: nil, include_grouped_by_values: true)
        prefix = alias_prefix ? "#{alias_prefix}." : ""

        conditions = [
          sql_condition("#{prefix}organization_id = ?", subscription.organization_id),
          sql_condition("#{prefix}code = ?", code),
          sql_condition("#{prefix}external_subscription_id = ?", subscription.external_id),
          sql_condition("#{prefix}charge_id = ?", charge_id),
          sql_condition("#{prefix}charge_filter_id = ?", charge_filter_id || "")
        ]

        conditions << sql_condition("#{prefix}timestamp >= ?", from_datetime) if from_datetime
        conditions << sql_condition("#{prefix}timestamp <= ?", to_datetime) if to_datetime
        conditions << grouped_by_values_sql_condition(prefix) if include_grouped_by_values && grouped_by_values?

        conditions.join(" AND ")
      end

      def code_based_fallback_where_sql(from_datetime:, alias_prefix: nil, include_grouped_by_values: true, include_filters: true)
        prefix = alias_prefix ? "#{alias_prefix}." : ""

        conditions = [
          sql_condition("#{prefix}organization_id = ?", subscription.organization_id),
          sql_condition("#{prefix}code = ?", code),
          sql_condition("#{prefix}external_subscription_id = ?", subscription.external_id),
          sql_condition("#{prefix}timestamp < ?", subscription.started_at)
        ]

        conditions << sql_condition("#{prefix}timestamp >= ?", from_datetime) if from_datetime

        if include_filters
          matching_filters.each do |key, values|
            conditions << sql_condition("#{prefix}sorted_properties[?] IN (?)", key.to_s, values.map(&:to_s))
          end

          ignored_clauses = ignored_filters.filter_map do |filters|
            next if filters.empty?

            inner = filters.filter_map do |key, values|
              next if values.empty?

              sql_condition("(coalesce(#{prefix}sorted_properties[?], '') IN (?))", key.to_s, values.map(&:to_s))
            end.join(" AND ")
            inner.presence
          end
          conditions << "NOT (#{ignored_clauses.map { "(#{it})" }.join(" OR ")})" if ignored_clauses.any?
        end

        conditions << grouped_by_values_via_properties_sql_condition(prefix) if include_grouped_by_values && grouped_by_values?

        conditions.join(" AND ")
      end

      def grouped_by_values_sql_condition(prefix)
        map_args = grouped_by_values
          .sort_by { |k, _| k }
          .flat_map { |k, v| [quote(k), quote(v.presence || "")] }
          .join(", ")
        "#{prefix}sorted_grouped_by = map(#{map_args})"
      end

      # Fallback events come from a previous subscription's charges, so `sorted_grouped_by`
      # reflects that charge's configuration and may not match the current grouped_by keys.
      # Filter against `sorted_properties` directly to stay charge-agnostic.
      def grouped_by_values_via_properties_sql_condition(prefix)
        grouped_by_values.map do |key, value|
          if value.present?
            sql_condition("#{prefix}sorted_properties[?] = ?", key.to_s, value.to_s)
          else
            sql_condition("coalesce(#{prefix}sorted_properties[?], '') = ''", key.to_s)
          end
        end.join(" AND ")
      end

      def needs_code_based_fallback?(force_from:)
        return false if subscription.previous_subscription_id.blank?
        return false if use_from_boundary

        effective_from = from_datetime if force_from
        effective_from.nil? || effective_from < subscription.started_at
      end

      def charge_id_based_query(from_datetime:, to_datetime:)
        arel_table.where(Arel.sql(charge_id_based_where_sql(from_datetime:, to_datetime:)))
      end

      # Fallback query filtering by code + properties instead of charge_id/charge_filter_id.
      # Used for events before subscription.started_at (from a previous subscription's charges).
      def code_based_fallback_query(from_datetime:)
        arel_table.where(Arel.sql(code_based_fallback_where_sql(from_datetime:)))
      end

      def prepare_grouped_result(result, decimal: false, groups_key: :groups, value_key: :value)
        result.to_ary.map do |row|
          row.symbolize_keys.tap do |r|
            r[:groups] = r[groups_key].transform_values(&:presence)
            r[:value] = decimal ? BigDecimal(r[value_key].presence || 0) : r[value_key]
            r.slice!(:groups, :value, :timestamp)
          end
        end
      end

      # NOTE: like prepare_grouped_result but each row also carries an events_count
      #       column, returned as GroupedAggregationResult.
      def prepare_grouped_aggregated_values(result, decimal: false)
        result.to_ary.map do |row|
          r = row.symbolize_keys

          GroupedAggregationResult.new(
            groups: r[:groups].transform_values(&:presence),
            value: decimal ? BigDecimal(r[:value].presence || 0) : r[:value],
            events_count: r[:events_count].presence&.to_i
          )
        end
      end

      # NOTE: like prepare_grouped_aggregated_values but each row also carries a prorated
      #       value column, returned as GroupedProratedAggregationResult.
      def prepare_grouped_prorated_values(result)
        result.to_ary.map do |row|
          r = row.symbolize_keys

          build_grouped_prorated_aggregation_result(
            groups: r[:groups].transform_values(&:presence),
            prorated_value: r[:prorated_value],
            value: r[:value],
            events_count: r[:events_count]
          )
        end
      end

      # NOTE: parses the grouped weighted_sum rows. Each row carries the weighted aggregation, the
      #       sum of the differences (including the initial value) and the rows count (including the
      #       2 boundary rows). Correction is delegated to build_grouped_weighted_result.
      def prepare_grouped_weighted_values(result, initial_values)
        result.to_ary.map do |row|
          r = row.symbolize_keys

          build_grouped_weighted_result(
            groups: r[:grouped_by].transform_values(&:presence),
            value: BigDecimal(r[:aggregation].presence || 0),
            variation_with_initial: BigDecimal(r[:variation_with_initial].presence || 0),
            rows_count: r[:rows_count].to_i,
            initial_values:
          )
        end
      end
    end
  end
end
