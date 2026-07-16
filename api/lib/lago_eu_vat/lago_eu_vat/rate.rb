# frozen_string_literal: true

module LagoEuVat
  class Rate
    COUNTRY_RATES = begin
      file_path = Rails.root.join("lib/lago_eu_vat/lago_eu_vat/eu_vat_rates.json")
      json_file = File.read(file_path)
      rates = JSON.parse(json_file)["items"]
      rates.freeze
    end

    class << self
      def country_codes
        COUNTRY_RATES.keys
      end

      def country_rates(country_code:)
        # NOTE: country rates are ordered by date, so we select the most recent applicable
        country_rates = COUNTRY_RATES[country_code].select do |period|
          Time.zone.now >= DateTime.parse(period["effective_from"])
        end

        rates = country_rates.first.fetch("rates")
        exceptions = country_rates.first.fetch("exceptions", [])

        {rates:, exceptions:}
      end
    end
  end
end
