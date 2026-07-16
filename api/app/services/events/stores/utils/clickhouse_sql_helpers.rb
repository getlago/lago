# frozen_string_literal: true

module Events
  module Stores
    module Utils
      module ClickhouseSqlHelpers
        DECIMAL_SCALE = 26
        DECIMAL_DATE_SCALE = 10

        # NOTE: Compute pro-rata of the duration in days between the datetimes over the duration of the billing period
        #       Dates are in customer timezone to make sure the duration is good
        def duration_ratio_sql(from, to, duration, timezone)
          from_in_timezone = date_in_customer_timezone_sql(from, timezone)
          to_in_timezone = date_in_customer_timezone_sql(to, timezone)

          "(date_diff('days', #{from_in_timezone}, #{to_in_timezone}) + 1) / #{duration}"
        end

        def date_in_customer_timezone_sql(date_value, timezone)
          sql = if date_value.is_a?(String)
            # NOTE: date is a table field name, example: events_enriched.timestamp
            "toTimezone(#{date_value}, :timezone)"
          else
            "toTimezone(toDateTime64(:date, 5, 'UTC'), :timezone)"
          end

          ActiveRecord::Base.sanitize_sql_for_conditions(
            [sql, {date: date_value, timezone:}]
          )
        end

        def quote(value)
          ::Clickhouse::BaseRecord.connection.quote(value)
        end

        # NOTE: A numeric literal containing a decimal point (e.g. 2500.0) is parsed as a Float64 by
        #       ClickHouse and loses precision when cast to Decimal. Rendering the value as a
        #       fixed-point string makes toDecimalXX read an exact decimal literal instead.
        def decimal_literal(value)
          BigDecimal(value.to_s).to_s("F")
        end

        def sql_condition(template, *values)
          ActiveRecord::Base.sanitize_sql_for_conditions([template, *values])
        end
      end
    end
  end
end
