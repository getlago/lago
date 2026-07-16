# frozen_string_literal: true

class AdjustedFee < ApplicationRecord
  belongs_to :invoice
  belongs_to :subscription
  belongs_to :fee, optional: true
  belongs_to :charge, optional: true
  belongs_to :fixed_charge, optional: true
  belongs_to :charge_with_discarded,
    -> { with_discarded },
    class_name: "Charge",
    foreign_key: :charge_id,
    optional: true
  belongs_to :fixed_charge_with_discarded,
    -> { with_discarded },
    class_name: "FixedCharge",
    foreign_key: :fixed_charge_id,
    optional: true
  belongs_to :group, optional: true
  belongs_to :charge_filter, optional: true
  belongs_to :charge_filter_with_discarded,
    -> { with_discarded },
    class_name: "ChargeFilter",
    foreign_key: :charge_filter_id,
    optional: true
  belongs_to :organization

  ADJUSTED_FEE_TYPES = [
    :adjusted_units,
    :adjusted_amount
  ].freeze

  enum :fee_type, Fee::FEE_TYPES

  scope :matching_charge_boundaries, ->(boundaries) {
    where(fee_type: :charge)
      .where("(properties->>'charges_from_datetime')::timestamptz = ?", boundaries.charges_from_datetime&.iso8601(3))
      .where("(properties->>'charges_to_datetime')::timestamptz = ?", boundaries.charges_to_datetime&.iso8601(3))
  }

  def adjusted_display_name?
    adjusted_units.blank? && adjusted_amount.blank?
  end
end

# == Schema Information
#
# Table name: adjusted_fees
# Database name: primary
#
#  id                        :uuid             not null, primary key
#  adjusted_amount           :boolean          default(FALSE), not null
#  adjusted_units            :boolean          default(FALSE), not null
#  fee_type                  :integer
#  grouped_by                :jsonb            not null
#  invoice_display_name      :string
#  properties                :jsonb            not null
#  unit_amount_cents         :bigint           default(0), not null
#  unit_precise_amount_cents :decimal(40, 15)  default(0.0), not null
#  units                     :decimal(, )      default(0.0), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  charge_filter_id          :uuid
#  charge_id                 :uuid
#  fee_id                    :uuid
#  fixed_charge_id           :uuid
#  group_id                  :uuid
#  invoice_id                :uuid             not null
#  organization_id           :uuid             not null
#  subscription_id           :uuid
#
# Indexes
#
#  index_adjusted_fees_on_charge_filter_id  (charge_filter_id)
#  index_adjusted_fees_on_charge_id         (charge_id)
#  index_adjusted_fees_on_fee_id            (fee_id)
#  index_adjusted_fees_on_group_id          (group_id)
#  index_adjusted_fees_on_invoice_id        (invoice_id)
#  index_adjusted_fees_on_organization_id   (organization_id)
#  index_adjusted_fees_on_subscription_id   (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (fee_id => fees.id)
#  fk_rails_...  (fixed_charge_id => fixed_charges.id)
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
