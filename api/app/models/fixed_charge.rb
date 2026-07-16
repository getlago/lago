# frozen_string_literal: true

class FixedCharge < ApplicationRecord
  include PaperTrailTraceable
  include ChargePropertiesValidation
  include Discard::Model

  self.discard_column = :deleted_at
  default_scope -> { kept }

  belongs_to :organization
  belongs_to :plan, -> { with_discarded }, touch: true
  belongs_to :add_on, -> { with_discarded }, touch: true
  belongs_to :parent, class_name: "FixedCharge", optional: true
  has_many :children, class_name: "FixedCharge", foreign_key: :parent_id, dependent: :nullify
  has_many :applied_taxes, class_name: "FixedCharge::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes
  has_many :fees
  has_many :events, class_name: "FixedChargeEvent", dependent: :destroy
  has_many :subscription_units_overrides, class_name: "Subscription::FixedChargeUnitsOverride"

  has_many :applied_taxes, class_name: "FixedCharge::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes

  scope :pay_in_advance, -> { where(pay_in_advance: true) }
  scope :pay_in_arrears, -> { where(pay_in_advance: false) }
  scope :parents, -> { where(parent_id: nil) }

  CHARGE_MODELS = {
    standard: "standard",
    graduated: "graduated",
    volume: "volume"
  }.freeze

  enum :charge_model, CHARGE_MODELS

  validates :units, numericality: {greater_than_or_equal_to: 0}
  validates :charge_model, :code, presence: true
  validates :pay_in_advance, exclusion: [nil]
  validates :prorated, exclusion: [nil]
  validates :properties, presence: true

  validate :validate_code_unique
  validate :validate_pay_in_advance
  validate :validate_prorated
  validate :validate_properties

  def equal_properties?(fixed_charge)
    charge_model == fixed_charge.charge_model &&
      properties == fixed_charge.properties &&
      units == fixed_charge.units
  end

  def effective_units_for(subscription)
    return units unless subscription

    subscription_units_overrides.find_by(subscription:)&.units || units
  end

  def parent_or_self
    if parent_id
      parent
    else
      self
    end
  end

  # When upgrading a subscription with fixed_charges paid_in_advance,
  # this exact charge might have already been paid at the beginning of billing period.
  # in case of prorating, we need to deduct the prorated amount (remaining of the billing_period)
  # that was already paid from the new price.
  def matching_fixed_charge_prev_subscription(subscription)
    return nil if subscription.previous_subscription.nil?

    subscription.previous_subscription.plan.fixed_charges.find_by(add_on_id:)
  end

  private

  def validate_pay_in_advance
    return unless pay_in_advance?

    if volume?
      errors.add(:pay_in_advance, :invalid_charge_model)
    end
  end

  # NOTE: A prorated fixed charge is valid in the following cases:
  # - standard model with any payment timing
  # - volume model with pay_in_arrears only
  # - graduated model with pay_in_arrears only
  # Graduated + pay_in_advance + prorated is NOT allowed
  def validate_prorated
    return unless prorated?

    if graduated? && pay_in_advance?
      errors.add(:prorated, :invalid_charge_model)
    end
  end

  def validate_properties
    return if properties.blank?

    validate_charge_model_properties(charge_model)
  end

  def validate_code_unique
    return unless plan
    return if parent_id?

    fixed_charge = plan.fixed_charges.parents.where(code:).first
    errors.add(:code, :taken) if fixed_charge && fixed_charge != self
  end
end

# == Schema Information
#
# Table name: fixed_charges
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  charge_model         :enum             default("standard"), not null
#  code                 :string           not null
#  deleted_at           :datetime
#  invoice_display_name :string
#  pay_in_advance       :boolean          default(FALSE), not null
#  properties           :jsonb            not null
#  prorated             :boolean          default(FALSE), not null
#  units                :decimal(30, 10)  default(0.0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  add_on_id            :uuid             not null
#  organization_id      :uuid             not null
#  parent_id            :uuid
#  plan_id              :uuid             not null
#
# Indexes
#
#  index_fixed_charges_on_add_on_id         (add_on_id)
#  index_fixed_charges_on_deleted_at        (deleted_at)
#  index_fixed_charges_on_organization_id   (organization_id)
#  index_fixed_charges_on_parent_id         (parent_id)
#  index_fixed_charges_on_plan_id           (plan_id)
#  index_fixed_charges_on_plan_id_and_code  (plan_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (parent_id IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (add_on_id => add_ons.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (plan_id => plans.id)
#
