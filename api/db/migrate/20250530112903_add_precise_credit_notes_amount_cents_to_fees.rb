# frozen_string_literal: true

class AddPreciseCreditNotesAmountCentsToFees < ActiveRecord::Migration[8.0]
  def change
    add_column :fees, :precise_credit_notes_amount_cents, :decimal, precision: 30, scale: 5, null: false, default: 0
  end
end
