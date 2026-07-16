# frozen_string_literal: true

module Common
  extend ActiveSupport::Concern

  private

  def valid_date?(date)
    Utils::Datetime.parse_iso8601_date(date).present?
  end
end
