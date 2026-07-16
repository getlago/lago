# frozen_string_literal: true

class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :url_invalid) unless url_valid?(value)
  end

  private

  def url_valid?(url)
    url = URI.parse(url)
    url.host.present? && (url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS))
  rescue
    false
  end
end
