# frozen_string_literal: true

class ChangeUniqueIndexInPayments < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    remove_index :payments, %i[payable_id payable_type]

    add_index :payments,
      %i[payable_id payable_type],
      where: "payable_payment_status in ('pending', 'processing') and payment_type = 'provider'",
      unique: true,
      algorithm: :concurrently
  end

  def down
    remove_index :payments, %i[payable_id payable_type]

    add_index :payments,
      %i[payable_id payable_type],
      where: "payable_payment_status in ('pending', 'processing')",
      unique: true,
      algorithm: :concurrently
  end
end
