# frozen_string_literal: true

class UsageThreshold < ApplicationRecord
  include PaperTrailTraceable
  include Currencies
  include Discard::Model

  self.discard_column = :deleted_at

  belongs_to :organization
  belongs_to :plan, optional: true
  belongs_to :subscription, optional: true

  has_many :applied_usage_thresholds
  has_many :invoices, through: :applied_usage_thresholds

  monetize :amount_cents, with_currency: ->(threshold) { threshold.currency }

  validates :amount_cents, numericality: {greater_than: 0}
  validates :amount_cents, uniqueness: {scope: %i[plan_id recurring deleted_at]}, if: -> { deleted_at.nil? && subscription_id.nil? }
  validates :recurring, uniqueness: {scope: %i[plan_id deleted_at]}, if: -> { recurring? && deleted_at.nil? && subscription_id.nil? }
  validate :exactly_one_parent_present

  scope :recurring, -> { where(recurring: true) }
  scope :not_recurring, -> { where(recurring: false) }

  default_scope -> { kept }

  def invoice_name
    threshold_display_name || I18n.t("invoice.usage_threshold")
  end

  def currency
    plan&.amount_currency || subscription&.plan_amount_currency || organization.default_currency
  end

  private

  def exactly_one_parent_present
    has_plan = plan_id.present? || plan.present?
    has_subscription = subscription_id.present? || subscription.present?

    return if has_plan && !has_subscription
    return if !has_plan && has_subscription

    errors.add(:base, "one_of_plan_or_subscription_required")
  end
end

# == Schema Information
#
# Table name: usage_thresholds
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  amount_cents           :bigint           not null
#  deleted_at             :datetime
#  recurring              :boolean          default(FALSE), not null
#  threshold_display_name :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  organization_id        :uuid             not null
#  plan_id                :uuid
#  subscription_id        :uuid
#
# Indexes
#
#  idx_usage_thresholds_on_amount_plan_recurring          (amount_cents,plan_id,recurring) UNIQUE WHERE ((deleted_at IS NULL) AND (plan_id IS NOT NULL))
#  idx_usage_thresholds_on_amount_subscription_recurring  (amount_cents,subscription_id,recurring) UNIQUE WHERE ((deleted_at IS NULL) AND (subscription_id IS NOT NULL))
#  idx_usage_thresholds_plan_recurring                    (plan_id,recurring) UNIQUE WHERE ((recurring IS TRUE) AND (deleted_at IS NULL) AND (plan_id IS NOT NULL))
#  idx_usage_thresholds_subscription_recurring            (subscription_id,recurring) UNIQUE WHERE ((recurring IS TRUE) AND (deleted_at IS NULL) AND (subscription_id IS NOT NULL))
#  index_usage_thresholds_on_organization_id              (organization_id)
#  index_usage_thresholds_on_plan_id                      (plan_id)
#  index_usage_thresholds_on_subscription_id              (subscription_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (plan_id => plans.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
