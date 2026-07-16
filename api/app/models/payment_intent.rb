# frozen_string_literal: true

class PaymentIntent < ApplicationRecord
  STATUSES = [:active, :expired].freeze

  belongs_to :invoice
  belongs_to :organization

  enum :status, STATUSES

  attribute :expires_at, default: -> { 24.hours.from_now }

  validates :status, :expires_at, presence: true
  validates :status, uniqueness: {scope: :invoice_id}, if: :active?

  scope :awaiting_expiration, -> { active.where("expires_at <= ?", Time.current) }
  scope :non_expired, -> { where("expires_at > ?", Time.current) }
end

# == Schema Information
#
# Table name: payment_intents
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  expires_at          :datetime         not null
#  payment_url         :string
#  status              :integer          default("active"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  invoice_id          :uuid             not null
#  organization_id     :uuid             not null
#  provider_session_id :string
#
# Indexes
#
#  index_payment_intents_on_invoice_id             (invoice_id)
#  index_payment_intents_on_invoice_id_and_status  (invoice_id,status) UNIQUE WHERE (status = 0)
#  index_payment_intents_on_organization_id        (organization_id)
#
