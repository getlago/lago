# frozen_string_literal: true

module Types
  class TimezoneEnum < Types::BaseEnum
    Timezones.all
      .uniq { |tz| tz.tzinfo.identifier }
      .each_with_object([]) { |tz, result| result << tz.tzinfo.identifier }
      .sort_by { |tz| tz.split("/") }
      .map do |tz|
        symbol = tz.gsub(/[^_a-zA-Z0-9]/, "_").squeeze("_").upcase
        value = tz

        if tz == "Etc/UTC"
          symbol = "UTC"
          value = "UTC"
        end

        value("TZ_#{symbol}", value, value:)
      end
  end
end
