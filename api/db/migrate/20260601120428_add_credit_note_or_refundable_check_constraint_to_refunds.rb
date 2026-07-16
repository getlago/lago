# frozen_string_literal: true

class AddCreditNoteOrRefundableCheckConstraintToRefunds < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :refunds,
      "credit_note_id IS NOT NULL OR (refundable_type IS NOT NULL AND refundable_id IS NOT NULL)",
      name: "refunds_credit_note_or_refundable_present",
      validate: false
  end
end
