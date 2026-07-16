# frozen_string_literal: true

class PricingUnit < ApplicationRecord
  belongs_to :organization
  has_many :pricing_unit_usages, dependent: :destroy

  validates :name, :code, :short_name, presence: true
  validates :code, uniqueness: {scope: :organization_id}
  validates :description, length: {maximum: 600}, allow_nil: true
  validates :short_name, length: {maximum: 3}, allow_nil: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[code name]
  end

  def exponent
    2
  end

  def subunit_to_unit
    10**exponent
  end
end

# == Schema Information
#
# Table name: pricing_units
# Database name: primary
#
#  id              :uuid             not null, primary key
#  code            :string           not null
#  description     :text
#  name            :string           not null
#  short_name      :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_pricing_units_on_code_and_organization_id  (code,organization_id) UNIQUE
#  index_pricing_units_on_organization_id           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
