# frozen_string_literal: true

class Subscription::ActivationRule < ApplicationRecord
  self.table_name = "subscription_activation_rules"

  STI_MAPPING = {
    "payment" => "Subscription::ActivationRule::Payment"
  }.freeze

  STATUSES = {
    inactive: "inactive",
    pending: "pending",
    satisfied: "satisfied",
    declined: "declined", # rule was applicable but declined (e.g., declined after undergoing a manual approval process)
    failed: "failed",
    expired: "expired",
    not_applicable: "not_applicable"
  }.freeze

  FULFILLED_STATUSES = STATUSES.values_at(:satisfied, :not_applicable).freeze
  REJECTED_STATUSES = STATUSES.values_at(:failed, :expired, :declined).freeze

  TYPES = {
    payment: "payment"
  }.freeze

  belongs_to :subscription
  belongs_to :organization

  enum :status, STATUSES, validate: true
  enum :type, TYPES, validate: true

  validates :type, presence: true, inclusion: {in: STI_MAPPING.keys}

  scope :expirable, -> { pending.where("expires_at <= ?", Time.current) }
  scope :rejected, -> { where(status: REJECTED_STATUSES) }
  scope :fulfilled, -> { where(status: FULFILLED_STATUSES) }

  def self.find_sti_class(type_name)
    STI_MAPPING.fetch(type_name).constantize
  end

  def self.sti_name
    STI_MAPPING.invert.fetch(name)
  end

  def applicable?
    raise NotImplementedError, "#{self.class}#applicable? must be implemented"
  end

  def evaluate!
    evaluate_service_class.call!(rule: self)
  end

  private

  def evaluate_service_class
    type_module = self.class.name.demodulize
    "Subscriptions::ActivationRules::#{type_module}::EvaluateService".constantize
  end
end

# == Schema Information
#
# Table name: subscription_activation_rules
# Database name: primary
#
#  id              :uuid             not null, primary key
#  expires_at      :datetime
#  status          :enum             default("inactive"), not null
#  timeout_hours   :integer          default(0), not null
#  type            :enum             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  subscription_id :uuid             not null
#
# Indexes
#
#  idx_on_subscription_id_type_8feb7b9623                  (subscription_id,type) UNIQUE
#  index_activation_rules_pending_with_expiry              (status,expires_at) WHERE ((status = 'pending'::subscription_activation_rule_statuses) AND (expires_at IS NOT NULL))
#  index_subscription_activation_rules_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (subscription_id => subscriptions.id)
#
