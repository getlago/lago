# frozen_string_literal: true

module Clickhouse
  class EventsDeadLetter < BaseRecord
    self.table_name = "events_dead_letter"
    self.primary_key = nil

    belongs_to :organization
  end
end

# == Schema Information
#
# Table name: events_dead_letter
# Database name: clickhouse
#
#  code                     :string           not null
#  error_code               :string           not null
#  error_message            :string           not null
#  event                    :json             not null
#  failed_at                :datetime         not null
#  ingested_at              :datetime         not null
#  initial_error_message    :string           not null
#  timestamp                :datetime         not null
#  external_subscription_id :string           not null
#  organization_id          :string           not null
#  transaction_id           :string           not null
#
