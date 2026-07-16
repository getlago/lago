# frozen_string_literal: true

class ImageValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, _value)
    record.errors.add(attribute, :invalid_size) unless valid_size?(record, attribute)
    record.errors.add(attribute, :invalid_content_type) unless valid_extension?(record, attribute)
  end

  protected

  def valid_size?(record, attribute)
    record.__send__(attribute).blob.byte_size <= options[:max_size]
  end

  def valid_extension?(record, attribute)
    content_type = record.__send__(attribute).blob.content_type
    options[:authorized_content_type].include?(content_type)
  end
end
