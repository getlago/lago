# frozen_string_literal: true

module Clickhouse
  class EventsRaw < BaseRecord
    self.table_name = "events_raw"
    self.primary_key = nil

    def id
      "#{organization_id}-#{external_subscription_id}-#{transaction_id}-#{ingested_at.to_i}"
    end

    def created_at
      ingested_at
    end

    def billable_metric
      BillableMetric.find_by(code:, organization_id:)
    end

    def api_client
    end

    def ip_address
    end

    def subscription
      organization.subscriptions
        .where(external_id: external_subscription_id)
        .where("date_trunc('millisecond', started_at::timestamp) <= ?::timestamp", timestamp)
        .where("terminated_at is NULL OR date_trunc('millisecond', terminated_at::timestamp) >= ?::timestamp", timestamp)
        .order("terminated_at DESC NULLS FIRST, started_at DESC")
        .first
    end

    def subscription_id
      subscription&.id
    end

    def organization
      Organization.find_by(id: organization_id)
    end

    private

    delegate :customer, :customer_id, to: :subscription, allow_nil: true
  end
end

# == Schema Information
#
# Table name: events_raw
# Database name: clickhouse
#
#  code                       :string           not null
#  ingested_at                :datetime         not null
#  precise_total_amount_cents :decimal(40, 15)
#  properties                 :string           not null
#  timestamp                  :datetime         not null
#  external_customer_id       :string           not null
#  external_subscription_id   :string           not null
#  organization_id            :string           not null
#  transaction_id             :string           not null
#
