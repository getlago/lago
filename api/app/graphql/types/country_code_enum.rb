# frozen_string_literal: true

module Types
  class CountryCodeEnum < Types::BaseEnum
    graphql_name "CountryCode"

    ISO3166::Country.all.each do |country| # rubocop:disable Rails/FindEach
      value country.alpha2, country.iso_short_name
    end
  end
end
