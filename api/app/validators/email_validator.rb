# frozen_string_literal: true

class EmailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid_email_format) unless valid?(value)
  end

  protected

  def valid?(value)
    return false if value.blank?

    # `-1` to keep empty emails after the last comma e.g. "user@domain.com,,"
    emails = value.split(",", -1).map(&:strip)

    emails.all? { |email| email.match?(Regex::EMAIL) }
  end
end
