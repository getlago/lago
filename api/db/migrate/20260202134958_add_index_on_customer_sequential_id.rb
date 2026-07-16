# frozen_string_literal: true

class AddIndexOnCustomerSequentialId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :customers, :sequential_id, algorithm: :concurrently
  end
end
