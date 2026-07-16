# frozen_string_literal: true

class Payment < ApplicationRecord
  include PaperTrailTraceable
  include RansackUuidSearch

  PAYABLE_PAYMENT_STATUS = %w[pending processing succeeded failed].freeze

  belongs_to :organization
  belongs_to :customer, -> { with_discarded }, optional: true
  belongs_to :payable, polymorphic: true
  belongs_to :payment_provider, optional: true, class_name: "PaymentProviders::BaseProvider"
  belongs_to :payment_provider_customer, optional: true, class_name: "PaymentProviderCustomers::BaseCustomer"
  belongs_to :payment_method, optional: true

  has_many :refunds
  has_many :integration_resources, as: :syncable
  has_one :invoice_settlement, foreign_key: :source_payment_id
  has_one :payment_receipt, dependent: :destroy

  alias_attribute :currency, :amount_currency

  monetize :amount_cents

  PAYMENT_TYPES = {provider: "provider", manual: "manual"}.freeze
  attribute :payment_type, :string
  enum :payment_type, PAYMENT_TYPES, default: :provider, prefix: :payment_type
  validates :payment_type, presence: true
  validates :reference, presence: true, length: {maximum: 40}, if: -> { payment_type_manual? }
  validates :reference, absence: true, if: -> { payment_type_provider? }
  validate :manual_payment_credit_invoice_amount_cents
  validate :max_invoice_paid_amount_cents, on: :create
  validate :payment_request_succeeded, on: :create

  enum :payable_payment_status, PAYABLE_PAYMENT_STATUS.map { |s| [s, s] }.to_h, validate: {allow_nil: true}

  delegate :billing_entity, to: :customer

  scope :for_organization, lambda { |organization|
    payables_join = ActiveRecord::Base.sanitize_sql_array([
      <<~SQL,
        LEFT JOIN invoices
          ON invoices.id = payments.payable_id
          AND payments.payable_type = 'Invoice'
          AND invoices.organization_id = :org_id
          AND invoices.status IN (:visible_statuses)
        LEFT JOIN payment_requests
          ON payment_requests.id = payments.payable_id
          AND payments.payable_type = 'PaymentRequest'
          AND payment_requests.organization_id = :org_id
      SQL
      {org_id: organization.id, visible_statuses: Invoice::VISIBLE_STATUS.values}
    ])
    joins(payables_join)
      .where("invoices.id IS NOT NULL OR payment_requests.id IS NOT NULL")
  }

  def self.ransackable_attributes(_ = nil)
    %w[id provider_payment_id reference] + _ransackers.keys
  end

  def self.ransackable_associations(_ = nil)
    %w[payable customer]
  end

  ransacker :invoice_number do
    Arel.sql("(SELECT invoices.number FROM invoices WHERE invoices.id = payments.payable_id AND payments.payable_type = 'Invoice' LIMIT 1)")
  end

  def invoices
    payable.payment_invoices
  end

  def invoice_numbers
    invoices.pluck(:number)
  end

  def should_sync_payment?
    return false unless payable.is_a?(Invoice)

    payable.finalized? && customer.integration_customers.accounting_kind.any? { |c| c.integration.sync_payments }
  end

  def payment_provider_type
    payment_provider&.payment_type
  end

  def method_display_name
    return nil if provider_payment_method_data.blank?

    type = provider_payment_method_data["type"]
    brand = provider_payment_method_data["brand"]

    if type == "card"
      "#{brand.to_s.titleize} #{card_last_digits}"
    else
      type.to_s.titleize
    end
  end

  def card_last_digits
    return nil if provider_payment_method_data.blank?
    return nil if provider_payment_method_data["type"] != "card"

    "**** #{provider_payment_method_data["last4"]}"
  end

  private

  def manual_payment_credit_invoice_amount_cents
    return if !payable.is_a?(Invoice) || payment_type_provider? || !payable.credit?
    return if amount_cents == payable.total_amount_cents

    errors.add(:amount_cents, :invalid_amount)
  end

  def max_invoice_paid_amount_cents
    return if !payable.is_a?(Invoice) || payment_type_provider?
    return if amount_cents <= payable.total_due_amount_cents

    errors.add(:amount_cents, :greater_than)
  end

  def payment_request_succeeded
    return if !payable.is_a?(Invoice) || payment_type_provider?

    return unless payable.payment_requests.where(payment_status: "succeeded").exists?

    errors.add(:base, :payment_request_is_already_succeeded)
  end
end

# == Schema Information
#
# Table name: payments
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  amount_cents                 :bigint           not null
#  amount_currency              :string           not null
#  error_code                   :string
#  payable_payment_status       :enum
#  payable_type                 :string           default("Invoice"), not null
#  payment_type                 :enum             default("provider"), not null
#  provider_payment_data        :jsonb
#  provider_payment_method_data :jsonb            not null
#  reference                    :string
#  status                       :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  customer_id                  :uuid
#  invoice_id                   :uuid
#  organization_id              :uuid             not null
#  payable_id                   :uuid
#  payment_method_id            :uuid
#  payment_provider_customer_id :uuid
#  payment_provider_id          :uuid
#  provider_payment_id          :string
#  provider_payment_method_id   :string
#
# Indexes
#
#  idx_on_organization_id_provider_payment_id_gin_trgm_2bcf073c0b  (organization_id,provider_payment_id) USING gin
#  index_payments_by_cursor                                        (organization_id,created_at DESC,id)
#  index_payments_on_customer_id                                   (customer_id)
#  index_payments_on_invoice_id                                    (invoice_id)
#  index_payments_on_organization_id                               (organization_id)
#  index_payments_on_organization_id_reference_gin_trgm_ops        (organization_id,reference) USING gin
#  index_payments_on_payable_id_and_payable_type                   (payable_id,payable_type) UNIQUE WHERE ((payable_payment_status = ANY (ARRAY['pending'::payment_payable_payment_status, 'processing'::payment_payable_payment_status])) AND (payment_type = 'provider'::payment_type))
#  index_payments_on_payable_id_and_payable_type_and_error_code    (payable_id,payable_type,error_code)
#  index_payments_on_payable_type_and_payable_id                   (payable_type,payable_id)
#  index_payments_on_payment_method_id                             (payment_method_id)
#  index_payments_on_payment_provider_customer_id                  (payment_provider_customer_id)
#  index_payments_on_payment_provider_id                           (payment_provider_id)
#  index_payments_on_payment_type                                  (payment_type)
#  index_payments_on_provider_payment_id_and_payment_provider_id   (provider_payment_id,payment_provider_id) UNIQUE WHERE (provider_payment_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_method_id => payment_methods.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
