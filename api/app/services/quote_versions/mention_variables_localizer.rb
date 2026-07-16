# frozen_string_literal: true

module QuoteVersions
  # Renders a raw, locale-independent mention-variables snapshot into localized display
  # strings. Pure transform: takes the raw dict plus a locale and returns a new dict.
  # Not a service (no DB access, no failure modes), so it has no BaseResult. Only the
  # locale-sensitive keys are transformed; every other key passes through unchanged, and
  # missing keys or nil values are tolerated.
  class MentionVariablesLocalizer
    DATE_KEYS = %w[quote_date commercial_terms_start_date].freeze

    def self.call(mention_variables:, locale:)
      new(mention_variables:, locale:).call
    end

    def initialize(mention_variables:, locale:)
      @mention_variables = mention_variables
      @locale = locale
    end

    def call
      I18n.with_locale(locale) do
        mention_variables.to_h { |key, value| [key, localize(key, value)] }
      end
    end

    private

    attr_reader :mention_variables, :locale

    def localize(key, value)
      case key
      when "commercial_terms_term_duration" then format_term_duration(value)
      when "commercial_terms_payment_terms" then format_payment_terms(value)
      when "billing_entity_address" then format_address(value)
      when *DATE_KEYS then format_date(value)
      else value
      end
    end

    def format_date(value)
      return if value.blank?

      I18n.l(Date.iso8601(value), format: :default)
    end

    def format_term_duration(value)
      return if value.blank?

      I18n.t("quote_version.mention_variables.term_duration.#{value["unit"]}", count: value["count"])
    end

    def format_payment_terms(value)
      return if value.blank?

      I18n.t("quote_version.mention_variables.payment_terms", count: value)
    end

    def format_address(value)
      return if value.blank?

      address = Addressing::Address.new(
        address_line1: value["address_line1"].to_s,
        address_line2: value["address_line2"].to_s,
        locality: value["locality"].to_s,
        postal_code: value["postal_code"].to_s,
        administrative_area: value["administrative_area"].to_s,
        country_code: value["country_code"].to_s,
        locale: locale.to_s
      )

      Addressing::DefaultFormatter.new.format(address, locale: locale.to_s, html: false).presence
    end
  end
end
