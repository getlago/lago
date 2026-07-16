# frozen_string_literal: true

class Refund < ApplicationRecord
  include PaperTrailTraceable

  REASONS = {
    credit_note: "credit_note",
    subscription_activation_expired: "subscription_activation_expired"
  }.freeze

  belongs_to :payment
  belongs_to :credit_note, optional: true
  belongs_to :refundable, polymorphic: true, optional: true
  belongs_to :payment_provider, optional: true, class_name: "PaymentProviders::BaseProvider"
  belongs_to :payment_provider_customer, class_name: "PaymentProviderCustomers::BaseCustomer"
  belongs_to :organization

  enum :reason, REASONS, validate: {allow_nil: true}

  validates :refundable, presence: true, unless: :credit_note_present?

  private

  def credit_note_present?
    credit_note_id.present? || credit_note.present?
  end
end

# == Schema Information
#
# Table name: refunds
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  amount_cents                 :bigint           default(0), not null
#  amount_currency              :string           not null
#  reason                       :string
#  refundable_type              :string
#  status                       :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  credit_note_id               :uuid
#  organization_id              :uuid             not null
#  payment_id                   :uuid             not null
#  payment_provider_customer_id :uuid             not null
#  payment_provider_id          :uuid
#  provider_refund_id           :string           not null
#  refundable_id                :uuid
#
# Indexes
#
#  index_refunds_on_credit_note_id                (credit_note_id)
#  index_refunds_on_organization_id               (organization_id)
#  index_refunds_on_payment_id                    (payment_id)
#  index_refunds_on_payment_provider_customer_id  (payment_provider_customer_id)
#  index_refunds_on_payment_provider_id           (payment_provider_id)
#  index_refunds_on_refundable                    (refundable_type,refundable_id)
#
# Foreign Keys
#
#  fk_rails_...  (credit_note_id => credit_notes.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (payment_id => payments.id)
#  fk_rails_...  (payment_provider_customer_id => payment_provider_customers.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
