# frozen_string_literal: true

class AddOffsetAmountToCreditNotes < ActiveRecord::Migration[8.0]
  def change
    add_column :credit_notes, :offset_amount_cents, :bigint, default: 0, null: false
    add_column :credit_notes, :offset_amount_currency, :string
  end
end
