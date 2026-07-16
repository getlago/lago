# frozen_string_literal: true

class AddOriginalFeeIdToFees < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :fees, :original_fee, type: :uuid, index: {algorithm: :concurrently}
    add_foreign_key :fees, :fees, column: :original_fee_id, validate: false
  end
end
