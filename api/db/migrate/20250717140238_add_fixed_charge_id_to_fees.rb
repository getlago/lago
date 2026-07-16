# frozen_string_literal: true

class AddFixedChargeIdToFees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :fees, :fixed_charge, type: :uuid, index: {algorithm: :concurrently}
    add_foreign_key :fees, :fixed_charges, column: :fixed_charge_id, validate: false
  end
end
