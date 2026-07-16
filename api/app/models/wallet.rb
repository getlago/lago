# frozen_string_literal: true

class Wallet < ApplicationRecord
  include PaperTrailTraceable
  include Currencies

  belongs_to :customer, -> { with_discarded }
  belongs_to :organization
  belongs_to :payment_method, optional: true
  belongs_to :billing_entity, optional: true

  has_many :wallet_transactions
  has_many :recurring_transaction_rules

  has_many :wallet_targets
  has_many :billable_metrics, through: :wallet_targets

  has_many :alerts, class_name: "UsageMonitoring::Alert"
  has_many :triggered_alerts, class_name: "UsageMonitoring::TriggeredAlert"

  has_many :activity_logs,
    -> { order(logged_at: :desc) },
    class_name: "Clickhouse::ActivityLog",
    as: :resource

  has_one :metadata,
    class_name: "Metadata::ItemMetadata",
    as: :owner,
    dependent: :destroy

  has_many :applied_invoice_custom_sections,
    class_name: "Wallet::AppliedInvoiceCustomSection",
    dependent: :destroy
  has_many :selected_invoice_custom_sections,
    through: :applied_invoice_custom_sections,
    source: :invoice_custom_section

  monetize :balance_cents
  monetize :consumed_amount_cents
  monetize :ongoing_balance_cents, :ongoing_usage_balance_cents, with_model_currency: :balance_currency

  LOWEST_PRIORITY = 50

  REFRESH_RELEVANT_ATTRIBUTES = %w[code priority allowed_fee_types].freeze

  validates :rate_amount, numericality: {greater_than: 0}
  validates :currency, inclusion: {in: currency_list}
  validates :invoice_requires_successful_payment, exclusion: [nil]
  validates :paid_top_up_min_amount_cents, numericality: {greater_than: 0}, allow_nil: true
  validates :paid_top_up_max_amount_cents, numericality: {greater_than: 0}, allow_nil: true
  validates :priority, inclusion: {in: 1..LOWEST_PRIORITY}
  validates :balance_cents, numericality: {greater_than_or_equal_to: 0}, if: :traceable?
  validate :paid_top_up_max_greater_than_or_equal_min
  validate :unique_code_per_customer, if: :code_changed?

  STATUSES = [
    :active,
    :terminated
  ].freeze

  enum :status, STATUSES

  scope :expired, -> { where("wallets.expiration_at::timestamp(0) <= ?", Time.current) }
  scope :with_positive_balance, -> { where("balance_cents > 0") }
  scope :ready_to_be_refreshed, -> { where(ready_to_be_refreshed: true) }

  def self.in_application_order
    order(:priority, :created_at)
  end

  def billing_entity
    super || customer&.billing_entity
  end

  def mark_as_terminated!(timestamp = Time.zone.now)
    self.terminated_at ||= timestamp
    terminated!
  end

  def paid_top_up_min_credits
    return if paid_top_up_min_amount_cents.nil?

    WalletCredit.from_amount_cents(wallet: self, amount_cents: paid_top_up_min_amount_cents).credit_amount
  end

  def paid_top_up_max_credits
    return if paid_top_up_max_amount_cents.nil?

    WalletCredit.from_amount_cents(wallet: self, amount_cents: paid_top_up_max_amount_cents).credit_amount
  end

  def currency=(currency)
    self.balance_currency = currency
    self.consumed_amount_currency = currency
  end

  def currency
    balance_currency
  end

  def limited_fee_types?
    allowed_fee_types.present?
  end

  def limited_to_billable_metrics?
    billable_metrics.any?
  end

  private

  def paid_top_up_max_greater_than_or_equal_min
    return if paid_top_up_min_amount_cents.nil?
    return if paid_top_up_max_amount_cents.nil?

    if paid_top_up_max_amount_cents < paid_top_up_min_amount_cents
      errors.add(:paid_top_up_max_amount_cents, :must_be_greater_than_or_equal_min)
    end
  end

  def unique_code_per_customer
    return unless active?

    if code && Wallet.where(customer_id: customer_id, code: code, status: "active").where.not(id: id).exists?
      errors.add(:code, :taken)
    end
  end
end

# == Schema Information
#
# Table name: wallets
# Database name: primary
#
#  id                                  :uuid             not null, primary key
#  allowed_fee_types                   :string           default([]), not null, is an Array
#  balance_cents                       :bigint           default(0), not null
#  balance_currency                    :string           not null
#  code                                :string
#  consumed_amount_cents               :bigint           default(0), not null
#  consumed_amount_currency            :string           not null
#  consumed_credits                    :decimal(30, 5)   default(0.0), not null
#  credits_balance                     :decimal(30, 5)   default(0.0), not null
#  credits_ongoing_balance             :decimal(30, 5)   default(0.0), not null
#  credits_ongoing_usage_balance       :decimal(30, 5)   default(0.0), not null
#  depleted_ongoing_balance            :boolean          default(FALSE), not null
#  expiration_at                       :datetime
#  invoice_requires_successful_payment :boolean          default(FALSE), not null
#  last_balance_sync_at                :datetime
#  last_consumed_credit_at             :datetime
#  last_ongoing_balance_sync_at        :datetime
#  lock_version                        :integer          default(0), not null
#  name                                :string
#  ongoing_balance_cents               :bigint           default(0), not null
#  ongoing_usage_balance_cents         :bigint           default(0), not null
#  paid_top_up_max_amount_cents        :bigint
#  paid_top_up_min_amount_cents        :bigint
#  payment_method_type                 :enum             default("provider"), not null
#  priority                            :integer          default(50), not null
#  rate_amount                         :decimal(30, 5)   default(0.0), not null
#  ready_to_be_refreshed               :boolean          default(FALSE), not null
#  skip_invoice_custom_sections        :boolean          default(FALSE), not null
#  status                              :integer          not null
#  terminated_at                       :datetime
#  traceable                           :boolean          default(FALSE), not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  billing_entity_id                   :uuid
#  customer_id                         :uuid             not null
#  organization_id                     :uuid             not null
#  payment_method_id                   :uuid
#
# Indexes
#
#  index_uniq_wallet_code_per_customer               (customer_id,code) UNIQUE WHERE (status = 0)
#  index_wallets_on_billing_entity_id                (billing_entity_id)
#  index_wallets_on_customer_id                      (customer_id)
#  index_wallets_on_organization_id                  (organization_id)
#  index_wallets_on_organization_id_and_customer_id  (organization_id,customer_id)
#  index_wallets_on_payment_method_id                (payment_method_id)
#  index_wallets_on_ready_to_be_refreshed            (ready_to_be_refreshed) WHERE ready_to_be_refreshed
#
# Foreign Keys
#
#  fk_rails_...  (billing_entity_id => billing_entities.id)
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_method_id => payment_methods.id)
#
