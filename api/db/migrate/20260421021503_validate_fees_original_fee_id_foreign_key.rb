# frozen_string_literal: true

class ValidateFeesOriginalFeeIdForeignKey < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    validate_foreign_key :fees, column: :original_fee_id
  end
end
