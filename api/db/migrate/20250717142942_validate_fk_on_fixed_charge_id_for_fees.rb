# frozen_string_literal: true

class ValidateFkOnFixedChargeIdForFees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    validate_foreign_key :fees, :fixed_charges
  end
end
