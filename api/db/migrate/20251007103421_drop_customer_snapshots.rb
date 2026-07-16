# frozen_string_literal: true

class DropCustomerSnapshots < ActiveRecord::Migration[8.0]
  def up
    drop_table :customer_snapshots
  end
end
