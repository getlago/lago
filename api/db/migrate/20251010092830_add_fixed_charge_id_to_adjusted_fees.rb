# frozen_string_literal: true

class AddFixedChargeIdToAdjustedFees < ActiveRecord::Migration[8.0]
  def change
    add_column :adjusted_fees, :fixed_charge_id, :uuid
    add_foreign_key :adjusted_fees, :fixed_charges, column: :fixed_charge_id, validate: false
  end
end
