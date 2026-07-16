# frozen_string_literal: true

class ValidateCreditNoteOrRefundableCheckConstraintOnRefunds < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :refunds, name: "refunds_credit_note_or_refundable_present"
  end
end
