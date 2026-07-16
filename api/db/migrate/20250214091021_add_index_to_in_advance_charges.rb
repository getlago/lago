# frozen_string_literal: true

class AddIndexToInAdvanceCharges < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :charges,
      [:billable_metric_id],
      where: "deleted_at IS NULL AND pay_in_advance = TRUE",
      algorithm: :concurrently,
      name: "index_charges_pay_in_advance"
  end
end
