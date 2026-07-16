# frozen_string_literal: true

class AddErrorCodeToPayments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :payments, :error_code, :string

    add_index :payments,
      %i[payable_id payable_type error_code],
      algorithm: :concurrently
  end
end
