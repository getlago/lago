# frozen_string_literal: true

class AddCustomersCursorIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :customers,
      [:organization_id, :created_at, :id],
      order: {created_at: :desc, id: :asc},
      name: :index_customers_by_cursor,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
