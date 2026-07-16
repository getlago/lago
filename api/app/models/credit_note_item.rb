# frozen_string_literal: true

class CreditNoteItem < ApplicationRecord
  belongs_to :credit_note
  belongs_to :fee
  belongs_to :organization

  monetize :amount_cents

  validates :amount_cents, numericality: {greater_than_or_equal_to: 0}

  def applied_taxes
    credit_note.applied_taxes.where(tax_code: fee.applied_taxes.select("fees_taxes.tax_code"))
  end

  # This method returns item amount with coupons applied
  # coupons are applied proportionally to the way they're applied on corresponding fee
  # so knowing the item total proportion to fee total we can calculate item amount with coupons
  def sub_total_excluding_taxes_amount_cents
    return 0 if amount_cents.zero? || fee.amount_cents.zero?

    item_proportion_to_fee = amount_cents.to_f / fee.amount_cents
    item_proportion_to_fee * fee.sub_total_excluding_taxes_amount_cents
  end

  def fee_rate
    precise_amount_cents.fdiv(fee.precise_amount_cents.nonzero? || 1)
  end
end

# == Schema Information
#
# Table name: credit_note_items
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  amount_cents         :bigint           default(0), not null
#  amount_currency      :string           not null
#  precise_amount_cents :decimal(30, 5)   not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  credit_note_id       :uuid             not null
#  fee_id               :uuid
#  organization_id      :uuid             not null
#
# Indexes
#
#  index_credit_note_items_on_credit_note_id   (credit_note_id)
#  index_credit_note_items_on_fee_id           (fee_id)
#  index_credit_note_items_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (credit_note_id => credit_notes.id)
#  fk_rails_...  (fee_id => fees.id)
#  fk_rails_...  (organization_id => organizations.id)
#
