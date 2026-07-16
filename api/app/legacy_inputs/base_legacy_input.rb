# frozen_string_literal: true

class BaseLegacyInput
  def initialize(organization, args)
    @organization = organization
    @args = args&.to_h&.symbolize_keys
  end

  protected

  attr_reader :organization, :args

  def date_in_organization_timezone(date, end_of_day: false)
    return if date.blank?

    result = date.to_date.in_time_zone(organization&.timezone || "UTC")
    result = result.end_of_day if end_of_day
    result.utc
  end
end
