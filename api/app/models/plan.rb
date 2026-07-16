# frozen_string_literal: true

class Plan < ApplicationRecord
  include PaperTrailTraceable
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  belongs_to :parent, class_name: "Plan", optional: true

  has_one :minimum_commitment, -> { where(commitment_type: :minimum_commitment) }, class_name: "Commitment"
  has_one :metadata,
    class_name: "Metadata::ItemMetadata",
    as: :owner

  has_many :commitments
  has_many :charges, dependent: :destroy
  has_many :billable_metrics, through: :charges
  has_many :charge_filters, through: :charges, source: :filters
  has_many :fixed_charges, dependent: :destroy
  has_many :add_ons, through: :fixed_charges
  has_many :subscriptions
  has_many :customers, through: :subscriptions
  has_many :children, class_name: "Plan", foreign_key: :parent_id, dependent: :destroy
  has_many :coupon_targets
  has_many :coupons, through: :coupon_targets
  has_many :invoices, through: :subscriptions
  has_many :usage_thresholds

  has_many :applied_taxes, class_name: "Plan::AppliedTax", dependent: :destroy
  has_many :taxes, through: :applied_taxes
  has_many :entitlements, class_name: "Entitlement::Entitlement", dependent: :destroy
  has_many :entitlement_values, through: :entitlements, source: :values, class_name: "Entitlement::EntitlementValue", dependent: :destroy

  has_many :activity_logs,
    -> { order(logged_at: :desc) },
    class_name: "Clickhouse::ActivityLog",
    as: :resource

  INTERVALS = %i[
    weekly
    monthly
    yearly
    quarterly
    semiannual
  ].freeze

  enum :interval, INTERVALS, validate: true

  monetize :amount_cents

  validates :name, :code, presence: true
  validates :amount_currency, inclusion: {in: currency_list}
  validates :pay_in_advance, inclusion: {in: [true, false]}
  validate :validate_code_unique

  default_scope -> { kept }
  scope :parents, -> { where(parent_id: nil) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name code]
  end

  def is_parent?
    !is_child?
  end

  def is_child?
    parent_id.present?
  end

  def applicable_usage_thresholds
    (parent || self).usage_thresholds
  end

  def pay_in_arrears?
    !pay_in_advance
  end

  def attached_to_subscriptions?
    subscriptions.exists?
  end

  def has_trial?
    trial_period.present? && trial_period.positive?
  end

  def charges_billed_in_monthly_split_intervals?
    bill_charges_monthly? && (yearly? || semiannual?)
  end

  def fixed_charges_billed_in_monthly_split_intervals?
    bill_fixed_charges_monthly? && (yearly? || semiannual?)
  end

  def charges_or_fixed_charges_billed_in_monthly_split_intervals?
    charges_billed_in_monthly_split_intervals? || fixed_charges_billed_in_monthly_split_intervals?
  end

  def invoice_name
    invoice_display_name.presence || name
  end

  # NOTE: Method used to compare plan for upgrade / downgrade on
  #       a same duration basis. It is not intended to be used
  #       directly for billing/invoicing purpose
  def yearly_amount_cents
    return amount_cents if yearly?
    return amount_cents * 12 if monthly?
    return amount_cents * 4 if quarterly?
    return amount_cents * 2 if semiannual?

    amount_cents * 52
  end

  def active_subscriptions_count
    count = subscriptions.active.count
    return count unless children

    count + children.joins(:subscriptions).merge(Subscription.active).select("subscriptions.id").distinct.count
  end

  def customers_count
    count = subscriptions.active.select(:customer_id).distinct.count
    return count unless children

    count + children.joins(:subscriptions).merge(Subscription.active).select(:customer_id).distinct.count
  end

  def draft_invoices_count
    count = subscriptions.joins(:invoices).merge(Invoice.draft).select(:invoice_id).distinct.count
    return count unless children

    count + children.joins(:subscriptions).joins(:invoices).merge(Invoice.draft).select(:invoice_id).distinct.count
  end

  private

  def validate_code_unique
    return unless organization
    return if parent_id?

    plan = organization.plans.parents.where(code:).first
    errors.add(:code, :taken) if plan && plan != self
  end
end

# == Schema Information
#
# Table name: plans
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  amount_cents               :bigint           not null
#  amount_currency            :string           not null
#  bill_charges_monthly       :boolean
#  bill_fixed_charges_monthly :boolean          default(FALSE)
#  code                       :string           not null
#  deleted_at                 :datetime
#  description                :string
#  interval                   :integer          not null
#  invoice_display_name       :string
#  name                       :string           not null
#  pay_in_advance             :boolean          default(FALSE), not null
#  pending_deletion           :boolean          default(FALSE), not null
#  trial_period               :float
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :uuid             not null
#  parent_id                  :uuid
#
# Indexes
#
#  index_plans_on_bill_fixed_charges_monthly         (bill_fixed_charges_monthly) WHERE ((deleted_at IS NULL) AND (bill_fixed_charges_monthly IS TRUE))
#  index_plans_on_created_at                         (created_at)
#  index_plans_on_deleted_at                         (deleted_at)
#  index_plans_on_organization_id                    (organization_id)
#  index_plans_on_organization_id_and_code           (organization_id,code) UNIQUE WHERE ((deleted_at IS NULL) AND (parent_id IS NULL))
#  index_plans_on_organization_id_code_gin_trgm_ops  (organization_id,code) WHERE (deleted_at IS NULL) USING gin
#  index_plans_on_organization_id_name_gin_trgm_ops  (organization_id,name) WHERE (deleted_at IS NULL) USING gin
#  index_plans_on_parent_id                          (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (parent_id => plans.id)
#
