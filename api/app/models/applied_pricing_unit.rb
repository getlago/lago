# frozen_string_literal: true

class AppliedPricingUnit < ApplicationRecord
  belongs_to :organization
  belongs_to :pricing_unit
  belongs_to :pricing_unitable, polymorphic: true

  validates :conversion_rate, presence: true
  validates :conversion_rate, numericality: {greater_than: 0}
end

# == Schema Information
#
# Table name: applied_pricing_units
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  conversion_rate       :decimal(40, 15)  default(0.0), not null
#  pricing_unitable_type :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  organization_id       :uuid             not null
#  pricing_unit_id       :uuid             not null
#  pricing_unitable_id   :uuid             not null
#
# Indexes
#
#  index_applied_pricing_units_on_organization_id   (organization_id)
#  index_applied_pricing_units_on_pricing_unit_id   (pricing_unit_id)
#  index_applied_pricing_units_on_pricing_unitable  (pricing_unitable_type,pricing_unitable_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (pricing_unit_id => pricing_units.id)
#
