# frozen_string_literal: true

module Events
  module Stores
    class PostgresStore < BaseStore
      def events(force_from: false, ordered: false)
        scope = Event.where(external_subscription_id: subscription.external_id)
          .where(organization_id: subscription.organization.id)
          .where(code:)

        scope = scope.order(timestamp: :asc) if ordered

        scope = scope.from_datetime(from_datetime) if force_from || use_from_boundary
        scope = apply_to_boundary(scope) if applicable_to_datetime

        if numeric_property
          scope = scope.where(presence_condition)
            .where(numeric_condition)
        end

        scope = apply_grouped_by_values(scope) if grouped_by_values?
        filters_scope(scope)
      end

      def distinct_charges_and_filters(codes: nil)
        scope = EnrichedEvent.where(organization_id: subscription.organization_id)
          .where(subscription_id: subscription.id)
          .where(timestamp: from_datetime..to_datetime)

        scope = scope.where(code: codes) unless codes.nil?
        scope.distinct.pluck(:charge_id, :charge_filter_id)
      end

      # Returns the distinct [code, properties] combinations present in the events of the
      # period. Only properties present in the filter_keys are considered, so the result holds
      # only the dimensions that can be matched against charge filters.
      # An empty hash represents the default (no filter) bucket.
      def distinct_codes_and_property_combinations(codes:, filter_keys:)
        scope = Event.where(external_subscription_id: subscription.external_id)
          .where(organization_id: subscription.organization_id)
          .where(code: codes)
          .from_datetime(from_datetime)
          .to_datetime(applicable_to_datetime)

        scope
          .select(Arel.sql(<<~SQL.squish))
            DISTINCT events.code AS code,
            coalesce((
              SELECT jsonb_object_agg(props.key, props.value)
              FROM jsonb_each_text(events.properties) AS props(key, value)
              WHERE props.key = ANY(#{filter_keys_array_sql(filter_keys)})
            ), '{}'::jsonb) AS combination
          SQL
          .map { |row| [row.code, parse_combination(row)] }
      end

      def events_values(limit: nil, force_from: false, exclude_event: false)
        field_name = sanitized_property_name
        field_name = "(#{field_name})::numeric" if numeric_property

        scope = events(force_from:, ordered: true)
        scope = scope.where.not(transaction_id: filters[:event].transaction_id) if exclude_event
        scope = scope.limit(limit) if limit

        scope.pluck(Arel.sql(field_name))
      end

      def last_event
        events(ordered: true).last
      end

      def grouped_last_event
        groups = sanitized_grouped_by

        sql = events
          .order(Arel.sql((groups + ["events.timestamp DESC, created_at DESC"]).join(", ")))
          .select(
            [
              "DISTINCT ON (#{groups.join(", ")}) #{groups.join(", ")}",
              "events.timestamp",
              "(#{sanitized_property_name})::numeric AS value"
            ].join(", ")
          )
          .to_sql

        prepare_grouped_result(select_all(sql).rows, timestamp: true)
      end

      def prorated_events_values(total_duration)
        ratio_sql = duration_ratio_sql("events.timestamp", to_datetime, total_duration)

        events(ordered: true).pluck(Arel.sql("(#{sanitized_property_name})::numeric * (#{ratio_sql})::numeric"))
      end

      def count
        build_aggregation_result_from_value(events.count)
      end

      def grouped_count(columns = grouped_by)
        results = events
          .group(columns.map { sanitized_property_name(it) })
          .count
          .map { |group, value| [group, value].flatten }

        grouped_results_with_value_as_count(prepare_grouped_result(results, columns: columns))
      end

      # NOTE: check if an event created before the current on belongs to an active (as in present and not removed)
      #       unique property
      def active_unique_property?(event)
        previous_event = events.where.not(id: event.id)
          .where("events.properties @> ?", {aggregation_property => event.properties[aggregation_property]}.to_json)
          .where("events.timestamp < ?", event.timestamp)
          .order(timestamp: :desc)
          .first

        previous_event && (
          previous_event.properties["operation_type"].nil? ||
          previous_event.properties["operation_type"] == "add"
        )
      end

      def unique_count
        query = Events::Stores::Postgres::UniqueCountQuery.new(store: self)
        sql = sanitize_sql_for_conditions([query.query])
        result = select_one(sql)

        build_aggregation_result_from_value(result["aggregation"])
      end

      # NOTE: not used in production, only for debug purpose to check the computed values before aggregation
      def unique_count_breakdown
        query = Events::Stores::Postgres::UniqueCountQuery.new(store: self)
        select_all(
          sanitize_sql_for_conditions([query.breakdown_query])
        ).rows
      end

      def prorated_unique_count
        query = Events::Stores::Postgres::UniqueCountQuery.new(store: self)
        sql = sanitize_sql_for_conditions(
          [
            sanitize_colon(query.prorated_query),
            {
              from_datetime:,
              to_datetime:,
              timezone: customer.applicable_timezone
            }
          ]
        )
        result = select_one(sql)

        build_aggregation_result_from_value(result["aggregation"])
      end

      def prorated_unique_count_breakdown(with_remove: false)
        query = Events::Stores::Postgres::UniqueCountQuery.new(store: self)
        sql = sanitize_sql_for_conditions(
          [
            sanitize_colon(query.prorated_breakdown_query(with_remove:)),
            {
              from_datetime:,
              to_datetime:,
              timezone: customer.applicable_timezone
            }
          ]
        )
        select_all(sql).to_a
      end

      def grouped_unique_count(columns = grouped_by)
        # NOTE: Important to use a dup to avoid mutate the current object (self) to associate the columns
        duplicated_unique_count_store = dup
        duplicated_unique_count_store.grouped_by = columns

        query = Events::Stores::Postgres::UniqueCountQuery.new(store: duplicated_unique_count_store)

        sql = sanitize_sql_for_conditions(
          [query.grouped_query]
        )

        grouped_results_with_value_as_count(
          prepare_grouped_result(select_all(sql).rows, columns: columns)
        )
      end

      def grouped_prorated_unique_count
        query = Events::Stores::Postgres::UniqueCountQuery.new(store: self)
        sql = sanitize_sql_for_conditions(
          [
            sanitize_colon(query.grouped_prorated_query),
            {
              from_datetime:,
              to_datetime:,
              timezone: customer.applicable_timezone
            }
          ]
        )
        grouped_results_with_value_as_count(prepare_grouped_result(select_all(sql).rows))
      end

      def max(with_count: true)
        AggregationResult.new(
          value: events.maximum("(#{sanitized_property_name})::numeric") || 0,
          events_count: with_count ? events.count : nil
        )
      end

      def grouped_max(columns = grouped_by, with_count: true)
        groups = columns.map { sanitized_property_name(it) }

        results = events
          .group(groups)
          .pluck(
            Arel.sql(
              (groups + [
                "MAX((#{sanitized_property_name})::numeric)",
                with_count ? "COUNT(*)" : "NULL"
              ]).join(", ")
            )
          )

        prepare_grouped_aggregated_values(results, columns: columns)
      end

      def last(with_count: true)
        AggregationResult.new(
          value: events.order(timestamp: :desc, created_at: :desc).first&.properties&.[](aggregation_property),
          events_count: with_count ? events.count : nil
        )
      end

      def grouped_last(columns = grouped_by, with_count: true)
        sanitized_columns = columns.map { sanitized_property_name(it) }
        distinct_on_columns = grouped_by.present? ? grouped_by.map { sanitized_property_name(it) } : []

        sql = if distinct_on_columns.empty?
          count_select = with_count ? "COUNT(*) OVER ()" : "NULL"
          events
            .order(Arel.sql("events.timestamp DESC, created_at DESC"))
            .select("#{sanitized_columns.join(", ")}, (#{sanitized_property_name})::numeric AS value, #{count_select} AS events_count")
            .limit(1)
            .to_sql
        else
          count_select = with_count ? "COUNT(*) OVER (PARTITION BY #{distinct_on_columns.join(", ")})" : "NULL"
          events
            .order(Arel.sql((distinct_on_columns + ["events.timestamp DESC, created_at DESC"]).join(", ")))
            .select(
              "DISTINCT ON (#{distinct_on_columns.join(", ")}) #{sanitized_columns.join(", ")}, (#{sanitized_property_name})::numeric AS value, #{count_select} AS events_count"
            )
            .to_sql
        end

        prepare_grouped_aggregated_values(select_all(sql).rows, columns: columns)
      end

      def sum_precise_total_amount_cents
        events.sum(:precise_total_amount_cents)
      end

      def grouped_sum_precise_total_amount_cents
        results = events
          .group(sanitized_grouped_by)
          .sum(:precise_total_amount_cents)
          .map { |group, value| [group, value].flatten }

        prepare_grouped_result(results)
      end

      def sum(with_count: true)
        AggregationResult.new(
          value: events.sum("(#{sanitized_property_name})::numeric"),
          events_count: with_count ? events.count : nil
        )
      end

      def grouped_sum(columns = grouped_by, with_count: true)
        groups = columns.map { sanitized_property_name(it) }

        results = events
          .group(groups)
          .pluck(
            Arel.sql(
              (groups + [
                "SUM((#{sanitized_property_name})::numeric)",
                with_count ? "COUNT(*)" : "NULL"
              ]).join(", ")
            )
          )

        prepare_grouped_aggregated_values(results, columns: columns)
      end

      def prorated_sum(period_duration:, persisted_duration: nil)
        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql("events.timestamp", to_datetime, period_duration)
        end

        sql = <<-SQL
          SUM((#{sanitized_property_name})::numeric * (#{ratio})::numeric) AS prorated_value,
          SUM((#{sanitized_property_name})::numeric) AS value,
          COUNT(*) AS events_count
        SQL

        build_prorated_aggregation_result(select_one(events.select(sql).to_sql))
      end

      def grouped_prorated_sum(period_duration:, persisted_duration: nil)
        ratio = if persisted_duration
          persisted_duration.fdiv(period_duration)
        else
          duration_ratio_sql("events.timestamp", to_datetime, period_duration)
        end

        sum_sql = <<-SQL
          #{sanitized_grouped_by.join(", ")},
          SUM((#{sanitized_property_name})::numeric * (#{ratio})::numeric) AS prorated_value,
          SUM((#{sanitized_property_name})::numeric) AS value,
          COUNT(*) AS events_count
        SQL

        sql = events
          .group(sanitized_grouped_by)
          .select(sum_sql)
          .to_sql

        prepare_grouped_prorated_result(select_all(sql).rows)
      end

      def sum_date_breakdown
        date_field = ::Utils::Timezone.date_in_customer_timezone_sql(customer, "events.timestamp")

        events.group(Arel.sql("DATE(#{date_field})"))
          .order(Arel.sql("DATE(#{date_field}) ASC"))
          .pluck(Arel.sql("DATE(#{date_field}) AS date, SUM((#{sanitized_property_name})::numeric)"))
          .map do |row|
            {date: row.first.to_date, value: row.last}
          end
      end

      def weighted_sum(initial_value: 0)
        query = Events::Stores::Postgres::WeightedSumQuery.new(store: self)

        sql = sanitize_sql_for_conditions(
          [
            sanitize_colon(query.query),
            {
              from_datetime:,
              to_datetime: to_datetime.ceil,
              initial_value: initial_value || 0
            }
          ]
        )

        result = select_one(sql)

        build_weighted_aggregation_result(
          value: result["aggregation"] || 0,
          variation_with_initial: result["variation_with_initial"] || 0,
          rows_count: result["rows_count"].to_i,
          initial_value:
        )
      end

      def grouped_weighted_sum(columns = grouped_by, initial_value: 0, initial_values: [])
        # NOTE: Important to use a dup to avoid mutate the current object (self) to associate the columns
        duplicated_weighted_sum_store = dup
        duplicated_weighted_sum_store.grouped_by = columns

        baseline_initial_values = if initial_values.present?
          initial_values
        elsif initial_value.to_d.nonzero?
          [{groups: {}, value: initial_value}]
        else
          []
        end

        query = Events::Stores::Postgres::WeightedSumQuery.new(store: duplicated_weighted_sum_store)

        formatted_initial_values = duplicated_weighted_sum_store.formatted_weighted_sum_initial_values(baseline_initial_values)
        return [] if formatted_initial_values.empty?

        sql = sanitize_sql_for_conditions(
          [
            sanitize_colon(query.grouped_query(initial_values: formatted_initial_values)),
            {
              from_datetime:,
              to_datetime: to_datetime.ceil
            }
          ]
        )

        prepare_grouped_weighted_values(select_all(sql).rows, formatted_initial_values, columns: columns)
      end

      def formatted_weighted_sum_initial_values(initial_values)
        # NOTE: build the list of initial values for each groups
        #       from the events in the period
        formatted_initial_values = grouped_count.map do |group|
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

        formatted_initial_values
      end

      # NOTE: not used in production, only for debug purpose to check the computed values before aggregation
      def weighted_sum_breakdown(initial_value: 0)
        query = Events::Stores::Postgres::WeightedSumQuery.new(store: self)
        select_all(
          sanitize_sql_for_conditions(
            [
              sanitize_colon(query.breakdown_query),
              {
                from_datetime:,
                to_datetime: to_datetime.ceil,
                initial_value: initial_value || 0
              }
            ]
          )
        ).rows
      end

      # NOTE: For a pay-in-advance event, the upper boundary is the event's own timestamp.
      #       Events sharing the same timestamp are tie-broken
      #       by ingestion order (created_at, id) so each gets a distinct position. Otherwise
      #       they would all count each other and be priced as the last unit of the batch.
      def apply_to_boundary(scope)
        boundary_event = filters[:event] if boundaries[:max_timestamp]

        if boundary_event&.id
          scope.where(
            "events.timestamp < :to OR (events.timestamp = :to AND (events.created_at, events.id) <= " \
            "(SELECT boundary_event.created_at, boundary_event.id FROM events boundary_event WHERE boundary_event.id = :boundary_event_id))",
            to: applicable_to_datetime,
            boundary_event_id: boundary_event.id
          )
        else
          scope.to_datetime(applicable_to_datetime)
        end
      end

      def filters_scope(scope)
        matching_filters.each do |key, values|
          scope = scope.where(
            "events.properties ->> ? IN (?)",
            key.to_s,
            values.map(&:to_s)
          )
        end

        conditions = ignored_filters.filter_map do |filters|
          next if filters.empty?

          clause = filters.filter_map do |key, values|
            next if values.empty?

            sanitize_sql_for_conditions(
              ["(coalesce(events.properties ->> ?, '') IN (?))", key.to_s, values.map(&:to_s)]
            )
          end.join(" AND ")
          clause.presence
        end
        sql = conditions.map { "(#{it})" }.join(" OR ")
        scope = scope.where.not(sql) if sql.present?

        scope
      end

      def apply_grouped_by_values(scope)
        grouped_by_values.each do |grouped_by, grouped_by_value|
          scope = if grouped_by_value.present?
            scope.where("events.properties @> ?", {grouped_by.to_s => grouped_by_value.to_s}.to_json)
          else
            scope.where(
              sanitize_sql_for_conditions(["COALESCE(events.properties->>?, '') = ''", grouped_by])
            )
          end
        end

        scope
      end

      def sanitized_property_name(property = aggregation_property)
        sanitize_sql_for_conditions(
          ["events.properties->>?", property]
        )
      end

      def presence_condition
        "events.properties::jsonb ? '#{sanitize_sql_for_conditions(aggregation_property)}'"
      end

      def numeric_condition
        # NOTE: ensure property value is a numeric value
        "#{sanitized_property_name} ~ '^-?\\d+(\\.\\d+)?$'"
      end

      def sanitized_grouped_by
        grouped_by.map { sanitized_property_name(it) }
      end

      delegate :connection, to: :Event

      delegate :select_all, to: :connection
      delegate :select_one, to: :connection

      delegate :sanitize_sql_for_conditions, to: :"ActiveRecord::Base"

      # NOTE: Compute pro-rata of the duration in days between the datetimes over the duration of the billing period
      #       Dates are in customer timezone to make sure the duration is good
      def duration_ratio_sql(from, to, duration)
        from_in_timezone = ::Utils::Timezone.date_in_customer_timezone_sql(customer, from)
        to_in_timezone = ::Utils::Timezone.date_in_customer_timezone_sql(customer, to)

        "((DATE(#{to_in_timezone}) - DATE(#{from_in_timezone}))::numeric + 1) / #{duration}::numeric"
      end

      # NOTE: returns the values for each groups
      #       The result format will be an array of hash with the format:
      #       [{ groups: { 'cloud' => 'aws', 'region' => 'us_east_1' }, value: 12.9 }, ...]
      def prepare_grouped_result(rows, timestamp: false, columns: grouped_by)
        rows.map do |row|
          last_group = timestamp ? -2 : -1

          result = {
            groups: build_groups(row[...last_group], columns:),
            value: row.last
          }

          result[:timestamp] = row[-2] if timestamp

          result
        end
      end

      # NOTE: Same as prepare_grouped_result but the last two columns of each row are
      #       the aggregated value and the events count, returned as GroupedAggregationResult.
      def prepare_grouped_aggregated_values(rows, columns: grouped_by)
        rows.map do |row|
          GroupedAggregationResult.new(
            groups: build_groups(row[...-2], columns:),
            value: row[-2],
            events_count: row[-1]&.to_i
          )
        end
      end

      # NOTE: Same as prepare_grouped_aggregated_values but the last three columns of each
      #       row are the prorated value, the non-prorated value and the events count,
      #       returned as GroupedProratedAggregationResult.
      def prepare_grouped_prorated_result(rows, columns: grouped_by)
        rows.map do |row|
          build_grouped_prorated_aggregation_result(
            groups: build_groups(row[...-3], columns:),
            prorated_value: row[-3],
            value: row[-2],
            events_count: row[-1]
          )
        end
      end

      # NOTE: parses the grouped weighted_sum rows. The last three columns of each row are the weighted
      #       aggregation, the sum of the differences (including the initial value) and the rows count
      #       (including the 2 boundary rows). Correction is delegated to build_grouped_weighted_result.
      def prepare_grouped_weighted_values(rows, initial_values, columns: grouped_by)
        rows.map do |row|
          build_grouped_weighted_result(
            groups: build_groups(row[...-3], columns:),
            value: row[-3],
            variation_with_initial: row[-2] || 0,
            rows_count: row[-1].to_i,
            initial_values:
          )
        end
      end

      def operation_type_sql
        "COALESCE(events.properties->>'operation_type', 'add')"
      end

      def created_at_ordering_column
        "events.created_at"
      end

      def filter_keys_array_sql(filter_keys)
        return "ARRAY[]::text[]" if filter_keys.empty?

        quoted = filter_keys.map { ActiveRecord::Base.connection.quote(it) }.join(", ")
        "ARRAY[#{quoted}]::text[]"
      end

      def parse_combination(row)
        combination = row.read_attribute(:combination)
        return combination if combination.is_a?(Hash)

        combination.present? ? JSON.parse(combination) : {}
      end
    end
  end
end
