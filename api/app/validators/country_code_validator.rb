# frozen_string_literal: true

class CountryCodeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :country_code_invalid) unless valid?(value)
  end

  protected

  def valid?(value)
    value && ISO3166::Country.new(value).present?
  end
end
