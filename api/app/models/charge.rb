# frozen_string_literal: true

class Charge < ApplicationRecord
  include PaperTrailTraceable
  include Currencies
  include ChargePropertiesValidation
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  belongs_to :plan, -> { with_discarded }, touch: true
  belongs_to :billable_metric, -> { with_discarded }
  belongs_to :parent, class_name: "Charge", optional: true

  has_one :applied_pricing_unit, as: :pricing_unitable
  has_one :pricing_unit, through: :applied_pricing_unit

  has_many :children, class_name: "Charge", foreign_key: :parent_id, dependent: :nullify
  has_many :fees
  has_many :filters, dependent: :destroy, class_name: "ChargeFilter"
  has_many :filter_values, through: :filters, class_name: "ChargeFilterValue", source: :values

  has_many :applied_taxes, class_name: "Charge::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes

  EVENT_TARGET_WALLET_CODE = "target_wallet_code"

  CHARGE_MODELS = %i[
    standard
    graduated
    package
    percentage
    volume
    graduated_percentage
    custom
    dynamic
  ].freeze

  REGROUPING_PAID_FEES_OPTIONS = %i[invoice].freeze

  enum :charge_model, CHARGE_MODELS, validate: true

  attribute :regroup_paid_fees, :integer
  enum :regroup_paid_fees, REGROUPING_PAID_FEES_OPTIONS

  validate :validate_properties
  validate :validate_dynamic, if: -> { dynamic? }
  validates :min_amount_cents, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :charge_model, :code, presence: true

  validate :validate_code_unique
  validate :charge_model_allowance
  validate :validate_pay_in_advance
  validate :validate_regroup_paid_fees
  validate :validate_prorated
  validate :validate_min_amount_cents
  validate :validate_custom_model
  validate :validate_invoiceable_unless_pay_in_advance
  validate :validate_accepts_target_wallet, if: -> { accepts_target_wallet_changed? }

  default_scope -> { kept }

  scope :pay_in_advance, -> { where(pay_in_advance: true) }
  scope :parents, -> { where(parent_id: nil) }

  def pricing_group_keys
    properties["pricing_group_keys"].presence || properties["grouped_by"]
  end

  def presentation_group_keys
    properties["presentation_group_keys"].presence
  end

  def presentation_group_keys_values
    return [] if presentation_group_keys.blank?

    presentation_group_keys.map { |e| e.fetch("value", nil) }.compact
  end

  def presentation_group_keys_values_displayed_in_invoice
    return [] if presentation_group_keys.blank?

    presentation_group_keys
      .select { |e| e.dig("options", "display_in_invoice") == true }
      .map { |e| e.fetch("value", nil) }
      .compact
  end

  def equal_properties?(charge)
    charge_model == charge.charge_model && properties == charge.properties
  end

  def equal_applied_pricing_unit_rate?(another_charge)
    return false unless applied_pricing_unit && another_charge.applied_pricing_unit

    applied_pricing_unit.conversion_rate == another_charge.applied_pricing_unit.conversion_rate
  end

  # NOTE: If same charge is NOT included in upgraded plan we still want to bill it. However if new plan is using
  # the same charge it should not be billed since it is recurring and will be billed at the end of period
  def included_in_next_subscription?(subscription)
    return false if subscription.next_subscription.nil?

    next_subscription_charges = subscription.next_subscription.plan.charges

    return false if next_subscription_charges.blank?

    next_subscription_charges.pluck(:billable_metric_id).include?(billable_metric_id)
  end

  private

  def validate_properties
    validate_charge_model_properties(charge_model)
  end

  def validate_invoiceable_unless_pay_in_advance
    return if pay_in_advance? || invoiceable?

    errors.add(:invoiceable, :must_be_true_unless_pay_in_advance)
  end

  def validate_dynamic
    # Only sum aggregation is compatible with Dynamic Pricing for now
    return if billable_metric.sum_agg?

    errors.add(:charge_model, :invalid_aggregation_type_or_charge_model)
  end

  def validate_pay_in_advance
    return unless pay_in_advance?

    if volume? || !billable_metric.payable_in_advance?
      errors.add(:pay_in_advance, :invalid_aggregation_type_or_charge_model)
    end
  end

  # NOTE: regroup_paid_fees only works with pay_in_advance and non-invoiceable charges
  def validate_regroup_paid_fees
    return if regroup_paid_fees.nil?
    return if pay_in_advance? && !invoiceable?

    errors.add(:regroup_paid_fees, :only_compatible_with_pay_in_advance_and_non_invoiceable)
  end

  def validate_min_amount_cents
    return unless pay_in_advance? && min_amount_cents.positive?

    errors.add(:min_amount_cents, :not_compatible_with_pay_in_advance)
  end

  # NOTE: A prorated charge cannot be created in the following cases:
  # - for metered charges,
  # - for pay_in_arrears, price model cannot be package, graduated and percentage
  # - for pay_in_advance, price model cannot be package, graduated, percentage and volume
  # - for weighted_sum aggregation as it already apply pro-ration logic
  def validate_prorated
    return unless prorated?

    unless billable_metric.weighted_sum_agg?
      return if billable_metric.recurring? && pay_in_advance? && standard?
      return if billable_metric.recurring? && !pay_in_advance? && (standard? || volume? || graduated?)
    end

    errors.add(:prorated, :invalid_billable_metric_or_charge_model)
  end

  def validate_custom_model
    return unless custom?
    return if billable_metric.custom_agg?

    errors.add(:charge_model, :invalid_aggregation_type_or_charge_model)
  end

  def charge_model_allowance
    if graduated_percentage? && !License.premium?
      errors.add(:charge_model, :graduated_percentage_requires_premium_license)
    end
  end

  def validate_code_unique
    return unless plan
    return if parent_id?

    charge = plan.charges.parents.where(code:).first
    errors.add(:code, :taken) if charge && charge != self
  end

  def validate_accepts_target_wallet
    return unless accepts_target_wallet

    errors.add(:accepts_target_wallet, :feature_unavailable) unless organization.events_targeting_wallets_enabled?
  end
end

# == Schema Information
#
# Table name: charges
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  accepts_target_wallet :boolean          default(FALSE), not null
#  amount_currency       :string
#  charge_model          :integer          default("standard"), not null
#  code                  :string           not null
#  deleted_at            :datetime
#  invoice_display_name  :string
#  invoiceable           :boolean          default(TRUE), not null
#  min_amount_cents      :bigint           default(0), not null
#  pay_in_advance        :boolean          default(FALSE), not null
#  properties            :jsonb            not null
#  prorated              :boolean          default(FALSE), not null
#  regroup_paid_fees     :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  billable_metric_id    :uuid
#  organization_id       :uuid             not null
#  parent_id             :uuid
#  plan_id               :uuid
#
# Indexes
#
#  idx_on_plan_id_billable_metric_id_pay_in_advance_4a205974cb   (plan_id,billable_metric_id,pay_in_advance) WHERE (deleted_at IS NULL)
#  index_charges_on_accepts_target_wallet                        (accepts_target_wallet) WHERE (accepts_target_wallet = true)
#  index_charges_on_billable_metric_id                           (billable_metric_id) WHERE (deleted_at IS NULL)
#  index_charges_on_billable_metric_id_all                       (billable_metric_id)
#  index_charges_on_deleted_at                                   (deleted_at)
#  index_charges_on_organization_id                              (organization_id)
#  index_charges_on_parent_id                                    (parent_id)
#  index_charges_on_plan_id                                      (plan_id)
#  index_charges_on_plan_id_and_billable_metric_id_and_prorated  (plan_id,billable_metric_id,prorated) WHERE (deleted_at IS NULL)
#  index_charges_on_plan_id_and_code                             (plan_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (parent_id IS NULL))
#  index_charges_pay_in_advance                                  (billable_metric_id) WHERE ((deleted_at IS NULL) AND (pay_in_advance = true))
#
# Foreign Keys
#
#  fk_rails_...  (billable_metric_id => billable_metrics.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (parent_id => charges.id)
#  fk_rails_...  (plan_id => plans.id)
#
