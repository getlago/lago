# frozen_string_literal: true

module Clickhouse
  class EventsEnrichedExpanded < BaseRecord
    self.table_name = "events_enriched_expanded"
    self.primary_key = [
      :organization_id,
      :code,
      :external_subscription_id,
      :charge_id,
      :charge_filter_id,
      :timestamp
    ]
  end
end

# == Schema Information
#
# Table name: events_enriched_expanded
# Database name: clickhouse
#
#  aggregation_type           :string           not null
#  charge_filter_version      :datetime
#  charge_version             :datetime
#  code                       :string           not null, primary key
#  decimal_value              :decimal(38, 26)
#  enriched_at                :datetime         not null
#  grouped_by                 :json             not null
#  precise_total_amount_cents :decimal(40, 15)
#  properties                 :json             not null
#  sorted_grouped_by          :string           not null
#  sorted_properties          :string           not null
#  timestamp                  :datetime         not null, primary key
#  value                      :string
#  charge_filter_id           :string           default(""), not null, primary key
#  charge_id                  :string           default(""), not null, primary key
#  external_subscription_id   :string           not null, primary key
#  organization_id            :string           not null, primary key
#  plan_id                    :string           default(""), not null
#  subscription_id            :string           default(""), not null
#  transaction_id             :string           not null
#
