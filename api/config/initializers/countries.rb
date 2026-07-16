# frozen_string_literal: true

# NOTE: Kosovo does not have an ISO 3166-1 alpha-2 code yet and as such
# is not included in the "countries" gem.
# See related issue: https://github.com/countries/countries/issues/793
#
# As it was requested by multiple customers, we are registering as it an
# available country until the ISO 3166-1 alpha-2 code is assigned.
ISO3166::Data.register(
  alpha2: "XK",
  alpha3: "XKX",
  continent: "Europe",
  country_code: "383",
  currency_code: "EUR",
  distance_unit: "KM",
  gec: "KV",
  geo: {
    latitude: 42.5833,
    longitude: 21.0001,
    max_latitude: 43.139,
    max_longitude: 21.835,
    min_latitude: 41.877,
    min_longitude: 19.949,
    bounds: {
      northeast: {
        lat: 41.877,
        lng: 19.949
      },
      southwest: {
        lat: 43.139,
        lng: 21.835
      }
    }
  },
  international_prefix: "00",
  ioc: "KOS",
  iso_long_name: "Republic of Kosovo",
  iso_short_name: "Kosovo",
  languages_official: ["sq", "sr"],
  languages_spoken: ["sq", "sr"],
  nationality: "Kosovar",
  postal_code: true,
  postal_code_format: "\\d{5}",
  region: "Europe",
  start_of_week: "monday",
  subregion: "Southern Europe",
  unofficial_names: ["Kosovo", "Kosova", "Косово"],
  world_region: "EMEA",
  translations: {
    "en" => "Kosovo"
  }
)
