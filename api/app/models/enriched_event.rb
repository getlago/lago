# frozen_string_literal: true

class EnrichedEvent < EventsRecord
  belongs_to :event

  validates :code,
    :timestamp,
    :transaction_id,
    :external_subscription_id,
    :organization_id,
    :subscription_id,
    :plan_id,
    :charge_id,
    :enriched_at, presence: true
end

# == Schema Information
#
# Table name: enriched_events
# Database name: events
#
#  id                         :uuid             not null
#  code                       :string           not null
#  decimal_value              :decimal(40, 15)  default(0.0), not null
#  enriched_at                :datetime         not null
#  grouped_by                 :jsonb            not null
#  operation_type             :string
#  precise_total_amount_cents :decimal(40, 15)
#  target_wallet_code         :string
#  timestamp                  :datetime         not null
#  value                      :string
#  charge_filter_id           :uuid
#  charge_id                  :uuid             not null
#  event_id                   :uuid             not null
#  external_subscription_id   :string           not null
#  organization_id            :uuid             not null
#  plan_id                    :uuid             not null
#  subscription_id            :uuid             not null
#  transaction_id             :string           not null
#
# Indexes
#
#  idx_billing_on_enriched_events     (organization_id,subscription_id,charge_id,charge_filter_id,timestamp)
#  idx_lookup_on_enriched_events      (organization_id,external_subscription_id,code,timestamp)
#  idx_unique_on_enriched_events      (organization_id,external_subscription_id,transaction_id,timestamp,charge_id) UNIQUE
#  index_enriched_events_on_event_id  (event_id)
#
