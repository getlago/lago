# frozen_string_literal: true

class LanguageCodeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :language_code_invalid) unless valid?(value)
  end

  protected

  def valid?(value)
    value && I18n.available_locales.include?(value.to_sym)
  end
end
