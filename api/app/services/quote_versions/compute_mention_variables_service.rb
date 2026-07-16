# frozen_string_literal: true

module QuoteVersions
  class ComputeMentionVariablesService < BaseService
    Result = BaseResult[:mention_variables]

    def initialize(quote_version:)
      @quote_version = quote_version
      super
    end

    def call
      result.mention_variables = {
        "customer_name" => customer.display_name,
        "customer_email" => customer.email,
        "organization_name" => organization.name,
        "organization_logo" => organization.logo_url,
        "billing_entity_name" => billing_entity&.name,
        "billing_entity_legal_name" => billing_entity&.legal_name,
        "billing_entity_address" => billing_entity_address,
        "billing_entity_tax_id" => billing_entity&.tax_identification_number,
        "billing_entity_email" => billing_entity&.email,
        "quote_number" => quote.number,
        "quote_date" => quote_date,
        "quote_version" => quote_version.version.to_s,
        "quote_currency" => quote_version.currency,
        "commercial_terms_term_duration" => term_duration,
        "commercial_terms_start_date" => quote_version.start_date&.iso8601,
        "commercial_terms_payment_terms" => customer.applicable_net_payment_term
      }

      result
    end

    private

    attr_reader :quote_version

    delegate :quote, to: :quote_version
    delegate :customer, :organization, to: :quote
    delegate :billing_entity, to: :customer

    # Structured, locale-independent address parts. Formatting happens at read time in
    # QuoteVersions::MentionVariablesLocalizer.
    def billing_entity_address
      return if billing_entity.nil?

      {
        "address_line1" => billing_entity.address_line1,
        "address_line2" => billing_entity.address_line2,
        "locality" => billing_entity.city,
        "postal_code" => billing_entity.zipcode,
        "administrative_area" => billing_entity.state,
        "country_code" => billing_entity.country
      }
    end

    # The calendar date is frozen as a fact: the datetime is resolved in the customer
    # timezone, then stored as an ISO date string. Locale formatting is applied at read time.
    def quote_date
      quote.created_at.in_time_zone(customer.applicable_timezone).to_date.iso8601
    end

    # Picks the largest whole unit between the two dates (years, then months, then days)
    # and returns a raw { "unit", "count" } pair. A 12-month span becomes 1 year.
    def term_duration
      start_date = quote_version.start_date
      end_date = quote_version.end_date
      return if start_date.blank? || end_date.blank?

      months = whole_months_between(start_date, end_date)

      if months < 1
        {"unit" => "days", "count" => (end_date - start_date).to_i}
      elsif (months % 12).zero?
        {"unit" => "years", "count" => months / 12}
      else
        {"unit" => "months", "count" => months}
      end
    end

    # Whole calendar months between two dates, rounding down a partial trailing month.
    def whole_months_between(from, to)
      months = (to.year * 12 + to.month) - (from.year * 12 + from.month)
      (to.day < from.day) ? months - 1 : months
    end
  end
end
