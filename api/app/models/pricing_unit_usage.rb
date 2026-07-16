# frozen_string_literal: true

class PricingUnitUsage < ApplicationRecord
  belongs_to :organization
  belongs_to :fee
  belongs_to :pricing_unit

  validates :short_name, :conversion_rate, presence: true
  validates :conversion_rate, numericality: {greater_than: 0}

  attr_accessor :projected_amount_cents

  def self.build_from_fiat_amounts(amount:, unit_amount:, applied_pricing_unit:)
    pricing_unit = applied_pricing_unit.pricing_unit

    rounded_amount = amount.round(pricing_unit.exponent)
    amount_cents = rounded_amount * pricing_unit.subunit_to_unit
    precise_amount_cents = amount * pricing_unit.subunit_to_unit.to_d
    unit_amount_cents = unit_amount * pricing_unit.subunit_to_unit

    new(
      organization: pricing_unit.organization,
      pricing_unit:,
      short_name: pricing_unit.short_name,
      conversion_rate: applied_pricing_unit.conversion_rate,
      amount_cents:,
      precise_amount_cents:,
      unit_amount_cents:,
      precise_unit_amount: unit_amount
    )
  end

  def to_fiat_currency_cents(currency)
    adjusted_amount = amount_cents.to_d * conversion_rate / pricing_unit.subunit_to_unit
    adjusted_unit_amount = unit_amount_cents.to_d * conversion_rate / pricing_unit.subunit_to_unit

    {
      amount_cents: adjusted_amount.round(currency.exponent) * currency.subunit_to_unit,
      precise_amount_cents: adjusted_amount * currency.subunit_to_unit.to_d,
      unit_amount_cents: adjusted_unit_amount * currency.subunit_to_unit,
      precise_unit_amount: adjusted_unit_amount
    }
  end

  def currency
    PricingUnit.new(short_name:)
  end
end

# == Schema Information
#
# Table name: pricing_unit_usages
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amount_cents         :bigint           not null
#  conversion_rate      :decimal(40, 15)  default(0.0), not null
#  precise_amount_cents :decimal(40, 15)  default(0.0), not null
#  precise_unit_amount  :decimal(30, 15)  default(0.0), not null
#  short_name           :string           not null
#  unit_amount_cents    :bigint           default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  fee_id               :uuid             not null
#  organization_id      :uuid             not null
#  pricing_unit_id      :uuid             not null
#
# Indexes
#
#  index_pricing_unit_usages_on_fee_id           (fee_id)
#  index_pricing_unit_usages_on_organization_id  (organization_id)
#  index_pricing_unit_usages_on_pricing_unit_id  (pricing_unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (fee_id => fees.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (pricing_unit_id => pricing_units.id)
#
