# frozen_string_literal: true

class AddUnscopedIndexOnChargesBillableMetricId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :charges,
      :billable_metric_id,
      name: :index_charges_on_billable_metric_id_all,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
