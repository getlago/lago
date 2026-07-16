# frozen_string_literal: true

class RecurringTransactionRule < ApplicationRecord
  include PaperTrailTraceable

  belongs_to :wallet
  belongs_to :organization
  belongs_to :payment_method, optional: true

  has_many :applied_invoice_custom_sections,
    class_name: "RecurringTransactionRule::AppliedInvoiceCustomSection",
    dependent: :destroy
  has_many :selected_invoice_custom_sections,
    through: :applied_invoice_custom_sections,
    source: :invoice_custom_section

  validates :transaction_name, length: {minimum: 1, maximum: 255}, allow_nil: true
  validates :grants_target_top_up, inclusion: {in: [true, false]}, allow_nil: true, if: :target?
  validates :grants_target_top_up, exclusion: {in: [true, false]}, unless: :target?
  validate :target_ongoing_balance_not_below_threshold,
    if: -> { target_ongoing_balance_changed? || threshold_credits_changed? || method_changed? || trigger_changed? }

  STATUSES = [
    :active,
    :terminated
  ].freeze

  INTERVALS = [
    :weekly,
    :monthly,
    :quarterly,
    :yearly,
    :semiannual
  ].freeze

  METHODS = [
    :fixed,
    :target
  ].freeze

  TRIGGERS = [
    :interval,
    :threshold
  ].freeze

  enum :interval, INTERVALS
  enum :method, METHODS
  enum :trigger, TRIGGERS
  enum :status, STATUSES

  scope :active, -> { where(status: statuses[:active]).where("expiration_at IS NULL OR expiration_at > ?", Time.current) }
  scope :eligible_for_termination, -> {
    where(status: statuses[:active])
      .where("expiration_at IS NOT NULL AND expiration_at <= ?", Time.current)
  }
  scope :expired, -> { where("recurring_transaction_rules.expiration_at::timestamp(0) <= ?", Time.current) }

  def currently_active?
    active? && (expiration_at.nil? || expiration_at > Time.current)
  end

  def mark_as_terminated!(timestamp = Time.zone.now)
    self.terminated_at ||= timestamp
    terminated!
  end

  def apply_min_top_up_limits(credit_amount:)
    if ignore_paid_top_up_limits?
      credit_amount
    else
      credit_amount.clamp(wallet.paid_top_up_min_credits, nil)
    end
  end

  def invoice_custom_section_params
    section_ids = applied_invoice_custom_sections.pluck(:invoice_custom_section_id)
    return if section_ids.none? && !skip_invoice_custom_sections

    {skip_invoice_custom_sections:, invoice_custom_section_ids: section_ids}
  end

  def compute_paid_credits(ongoing_balance:)
    if target?
      return 0.0 if grants_target_top_up?

      compute_target_top_up_amount(ongoing_balance:)
    else
      paid_credits
    end
  end

  def compute_granted_credits
    if target?
      return compute_target_top_up_amount(ongoing_balance: wallet.credits_ongoing_balance) if grants_target_top_up?

      0.0
    else
      granted_credits
    end
  end

  private

  def target_ongoing_balance_not_below_threshold
    return unless target? && threshold?
    return if target_ongoing_balance.nil? || threshold_credits.nil?

    if target_ongoing_balance < threshold_credits
      errors.add(:target_ongoing_balance, :must_be_greater_than_or_equal_threshold)
    end
  end

  def compute_target_top_up_amount(ongoing_balance:)
    if ongoing_balance >= target_ongoing_balance
      return 0.0
    end

    gap = target_ongoing_balance - ongoing_balance

    # NOTE: granted top-ups skip the paid_top_up_min limit since no payment occurs
    return gap if grants_target_top_up?

    # NOTE: in case of target rule, we don't apply max because reaching target balance is the most important
    apply_min_top_up_limits(credit_amount: gap)
  end
end

# == Schema Information
#
# Table name: recurring_transaction_rules
# Database name: primary
#
#  id                                  :uuid             not null, primary key
#  expiration_at                       :datetime
#  granted_credits                     :decimal(30, 5)   default(0.0), not null
#  grants_target_top_up                :boolean
#  ignore_paid_top_up_limits           :boolean          default(FALSE), not null
#  interval                            :integer          default("weekly")
#  invoice_requires_successful_payment :boolean          default(FALSE), not null
#  method                              :integer          default("fixed"), not null
#  paid_credits                        :decimal(30, 5)   default(0.0), not null
#  payment_method_type                 :enum             default("provider"), not null
#  skip_invoice_custom_sections        :boolean          default(FALSE), not null
#  started_at                          :datetime
#  status                              :integer          default("active")
#  target_ongoing_balance              :decimal(30, 5)
#  terminated_at                       :datetime
#  threshold_credits                   :decimal(30, 5)   default(0.0)
#  transaction_metadata                :jsonb
#  transaction_name                    :string(255)
#  trigger                             :integer          default("interval"), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  organization_id                     :uuid             not null
#  payment_method_id                   :uuid
#  wallet_id                           :uuid             not null
#
# Indexes
#
#  index_recurring_transaction_rules_on_expiration_at      (expiration_at)
#  index_recurring_transaction_rules_on_organization_id    (organization_id)
#  index_recurring_transaction_rules_on_payment_method_id  (payment_method_id)
#  index_recurring_transaction_rules_on_started_at         (started_at)
#  index_recurring_transaction_rules_on_wallet_id          (wallet_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_method_id => payment_methods.id)
#  fk_rails_...  (wallet_id => wallets.id)
#
