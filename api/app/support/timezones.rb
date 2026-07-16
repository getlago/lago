# frozen_string_literal: true

module Timezones
  # Fixes a desync between the timezone names and the timezone identifiers
  # in rails and ruby
  MAPPING = ActiveSupport::TimeZone::MAPPING.merge({
    "Yangon" => "Asia/Yangon",
    "Kyiv" => "Europe/Kyiv",
    "Greenland" => "America/Nuuk"
  }).except("Rangoon")

  class << self
    def all
      MAPPING.each_with_object([]) do |(_, zone), result|
        result << ActiveSupport::TimeZone.new(zone)
      end
    end
  end
end
