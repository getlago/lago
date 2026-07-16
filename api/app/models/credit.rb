# frozen_string_literal: true

class Credit < ApplicationRecord
  include Currencies

  belongs_to :invoice
  belongs_to :applied_coupon, optional: true
  belongs_to :credit_note, optional: true
  belongs_to :progressive_billing_invoice, class_name: "Invoice", optional: true
  belongs_to :organization

  has_one :coupon, -> { with_discarded }, through: :applied_coupon

  monetize :amount_cents, disable_validation: true, allow_nil: true

  validates :amount_currency, inclusion: {in: currency_list}

  scope :coupon_kind, -> { where.not(applied_coupon_id: nil) }
  scope :credit_note_kind, -> { where.not(credit_note_id: nil) }
  scope :progressive_billing_invoice_kind, -> { where.not(progressive_billing_invoice_id: nil) }
  # Closed invoices (gated subscriptions that failed payment or timed out) never produced
  # value for the customer; their credits are released back to the source like voided ones.
  scope :active, -> { joins(:invoice).where.not(invoices: {status: %i[voided closed]}) }
  scope :voided, -> { joins(:invoice).where(invoices: {status: :voided}) }

  def item_id
    return coupon&.id if applied_coupon_id
    return progressive_billing_invoice_id if progressive_billing_invoice_id?

    credit_note.id
  end

  def item_type
    return "coupon" if applied_coupon_id?
    return "invoice" if progressive_billing_invoice_id?

    "credit_note"
  end

  def item_code
    return coupon&.code if applied_coupon_id?
    return progressive_billing_invoice.number if progressive_billing_invoice_id?

    credit_note.number
  end

  def item_name
    return coupon&.name if applied_coupon_id?
    return progressive_billing_invoice.number if progressive_billing_invoice_id?

    # TODO: change it depending on invoice template
    credit_note.invoice.number
  end

  def item_description
    return coupon&.description if applied_coupon_id?
    return credit_note.description if credit_note_id?

    nil
  end

  def invoice_coupon_display_name
    return nil if applied_coupon.blank?

    suffix = if coupon.percentage?
      "#{format("%.2f", applied_coupon.percentage_rate)}%"
    else
      applied_coupon.amount.format(
        format: I18n.t("money.format"),
        decimal_mark: I18n.t("money.decimal_mark"),
        thousands_separator: I18n.t("money.thousands_separator")
      )
    end

    "#{coupon.name} (#{suffix})"
  end
end

# == Schema Information
#
# Table name: credits
# Database name: primary
#
#  id                             :uuid             not null, primary key
#  amount_cents                   :bigint           not null
#  amount_currency                :string           not null
#  before_taxes                   :boolean          default(FALSE), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  applied_coupon_id              :uuid
#  credit_note_id                 :uuid
#  invoice_id                     :uuid
#  organization_id                :uuid             not null
#  progressive_billing_invoice_id :uuid
#
# Indexes
#
#  index_credits_on_applied_coupon_id               (applied_coupon_id)
#  index_credits_on_credit_note_id                  (credit_note_id)
#  index_credits_on_invoice_id                      (invoice_id)
#  index_credits_on_organization_id                 (organization_id)
#  index_credits_on_progressive_billing_invoice_id  (progressive_billing_invoice_id)
#
# Foreign Keys
#
#  fk_rails_...  (applied_coupon_id => applied_coupons.id)
#  fk_rails_...  (credit_note_id => credit_notes.id)
#  fk_rails_...  (invoice_id => invoices.id)
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (progressive_billing_invoice_id => invoices.id)
#
