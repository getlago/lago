# frozen_string_literal: true

class AddInAdvanceIndexToCharge < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :charges,
      [:plan_id, :billable_metric_id, :pay_in_advance],
      algorithm: :concurrently,
      using: :btree,
      where: "deleted_at IS NULL",
      if_not_exists: true
  end
end
