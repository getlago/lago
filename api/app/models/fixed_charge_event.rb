# frozen_string_literal: true

class FixedChargeEvent < ApplicationRecord
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  belongs_to :subscription
  belongs_to :fixed_charge

  validates :units, numericality: {greater_than_or_equal_to: 0}

  default_scope -> { kept }
end

# == Schema Information
#
# Table name: fixed_charge_events
# Database name: primary
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  timestamp       :datetime
#  units           :decimal(30, 10)  default(0.0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  fixed_charge_id :uuid             not null
#  organization_id :uuid             not null
#  subscription_id :uuid             not null
#
# Indexes
#
#  index_fixed_charge_events_on_deleted_at       (deleted_at)
#  index_fixed_charge_events_on_fixed_charge_id  (fixed_charge_id)
#  index_fixed_charge_events_on_organization_id  (organization_id)
#  index_fixed_charge_events_on_subscription_id  (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (fixed_charge_id => fixed_charges.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
