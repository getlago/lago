# frozen_string_literal: true

module Events
  class LastHourMv < ApplicationRecord
    self.table_name = "last_hour_events_mv"

    def readonly?
      true
    end
  end
end

# == Schema Information
#
# Table name: last_hour_events_mv
# Database name: primary
#
#  billable_metric_code    :string
#  field_name_mandatory    :boolean
#  field_value             :text
#  has_filter_keys         :boolean
#  has_valid_filter_values :boolean
#  is_numeric_field_value  :boolean
#  numeric_field_mandatory :boolean
#  properties              :jsonb
#  organization_id         :uuid
#  transaction_id          :string
#
