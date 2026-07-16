# frozen_string_literal: true

class Subscription::FixedChargeUnitsOverride < ApplicationRecord
  include Discard::Model
  include PaperTrailTraceable

  self.table_name = "subscription_fixed_charge_units_overrides"
  self.discard_column = :deleted_at
  default_scope -> { kept }

  belongs_to :organization
  belongs_to :subscription
  belongs_to :fixed_charge

  validates :units, presence: true, numericality: {greater_than_or_equal_to: 0}

  # Returns a {fixed_charge_id => units} map for the given subscription and
  # fixed_charges in one query. Lets collection callers (REST index, GraphQL
  # Subscription type) resolve subscription-aware units without an N+1.
  def self.units_map_for(subscription:, fixed_charges:)
    return {} unless subscription

    where(subscription:, fixed_charge_id: fixed_charges)
      .pluck(:fixed_charge_id, :units)
      .to_h
  end
end

# == Schema Information
#
# Table name: subscription_fixed_charge_units_overrides
# Database name: primary
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  units           :decimal(30, 10)  default(0.0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  fixed_charge_id :uuid             not null
#  organization_id :uuid             not null
#  subscription_id :uuid             not null
#
# Indexes
#
#  idx_on_fixed_charge_id_06503ae1a5                              (fixed_charge_id)
#  idx_on_organization_id_e742f77454                              (organization_id)
#  idx_on_subscription_id_bd763c5aa3                              (subscription_id)
#  index_sub_fc_units_overrides_on_sub_id_and_fc_id               (subscription_id,fixed_charge_id) UNIQUE WHERE (deleted_at IS NULL)
#  index_subscription_fixed_charge_units_overrides_on_deleted_at  (deleted_at)
#
# Foreign Keys
#
#  fk_rails_...  (fixed_charge_id => fixed_charges.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
