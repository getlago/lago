# frozen_string_literal: true

class EmailArrayValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.is_a? Array
      record.errors.add(attribute, "must_be_an_array")
      return
    end

    value.each_with_index do |email, index|
      unless valid? email
        record.errors.add(attribute, "invalid_email_format[#{index},#{email}]")
      end
    end
  end

  protected

  def valid?(value)
    value&.match(Regex::EMAIL)
  end
end
