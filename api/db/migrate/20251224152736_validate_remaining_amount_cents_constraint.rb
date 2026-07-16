# frozen_string_literal: true

class ValidateRemainingAmountCentsConstraint < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :wallet_transactions, name: "remaining_amount_cents_non_negative"
  end
end
