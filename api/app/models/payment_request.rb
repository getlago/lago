# frozen_string_literal: true

class PaymentRequest < ApplicationRecord
  include PaperTrailTraceable

  has_many :applied_invoices, class_name: "PaymentRequest::AppliedInvoice"
  has_many :invoices, through: :applied_invoices
  has_many :payments, as: :payable

  belongs_to :organization
  belongs_to :customer, -> { with_discarded }
  belongs_to :dunning_campaign, -> { with_discarded }, optional: true

  delegate :billing_entity, to: :customer

  validates :amount_cents, presence: true
  validates :amount_currency, presence: true

  PAYMENT_STATUS = %i[pending succeeded failed].freeze

  enum :payment_status, PAYMENT_STATUS, prefix: :payment

  alias_attribute :total_amount_cents, :amount_cents
  alias_attribute :currency, :amount_currency

  monetize :amount_cents
  monetize :total_due_amount_cents, with_model_currency: :currency, allow_nil: true

  normalizes :email, with: ->(email) { EmailSanitizer.call(email) }

  def self.ransackable_attributes(_ = nil)
    %w[id number]
  end

  def self.ransackable_associations(_ = nil)
    %w[customer]
  end

  def payment_invoices
    invoices
  end

  def invoice_ids
    applied_invoices.pluck(:invoice_id)
  end

  def increment_payment_attempts!
    increment(:payment_attempts)
    save!
  end

  def total_amount_cents=(total_amount_cents)
    self.amount_cents = total_amount_cents
  end

  def total_due_amount_cents
    (payment_status.to_sym == :succeeded) ? 0 : total_amount_cents
  end
end

# == Schema Information
#
# Table name: payment_requests
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  amount_cents                 :bigint           default(0), not null
#  amount_currency              :string           not null
#  email                        :string
#  payment_attempts             :integer          default(0), not null
#  payment_status               :integer          default("pending"), not null
#  ready_for_payment_processing :boolean          default(TRUE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  customer_id                  :uuid             not null
#  dunning_campaign_id          :uuid
#  organization_id              :uuid             not null
#
# Indexes
#
#  index_payment_requests_on_customer_id          (customer_id)
#  index_payment_requests_on_dunning_campaign_id  (dunning_campaign_id)
#  index_payment_requests_on_organization_id      (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (dunning_campaign_id => dunning_campaigns.id)
#  fk_rails_...  (organization_id => organizations.id)
#
