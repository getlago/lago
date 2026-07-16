# frozen_string_literal: true

class CachedAggregation < ApplicationRecord
  self.ignored_columns += %w[event_id]

  belongs_to :organization
  belongs_to :charge
  belongs_to :group, optional: true
  belongs_to :charge_filter, optional: true

  validates :external_subscription_id, presence: true
  validates :timestamp, presence: true

  scope :from_datetime, ->(from_datetime) { where("cached_aggregations.timestamp >= ?", from_datetime&.change(usec: 0)) }
  scope :to_datetime, ->(to_datetime) { where("cached_aggregations.timestamp <= ?", to_datetime&.change(usec: 0)) }
end

# == Schema Information
#
# Table name: cached_aggregations
# Database name: primary
#
#  id                             :uuid             not null, primary key
#  current_aggregation            :decimal(, )
#  current_amount                 :decimal(, )
#  grouped_by                     :jsonb            not null
#  max_aggregation                :decimal(, )
#  max_aggregation_with_proration :decimal(, )
#  presentation_breakdowns        :jsonb            not null
#  timestamp                      :datetime         not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  charge_filter_id               :uuid
#  charge_id                      :uuid             not null
#  event_transaction_id           :string
#  external_subscription_id       :string           not null
#  group_id                       :uuid
#  organization_id                :uuid             not null
#
# Indexes
#
#  idx_aggregation_lookup                                 (external_subscription_id,charge_id,timestamp)
#  idx_cached_aggregation_filtered_lookup                 (organization_id,external_subscription_id,charge_id,timestamp DESC,created_at DESC)
#  index_cached_aggregations_on_charge_id                 (charge_id)
#  index_cached_aggregations_on_event_transaction_id      (organization_id,event_transaction_id)
#  index_cached_aggregations_on_external_subscription_id  (external_subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (group_id => groups.id)
#
