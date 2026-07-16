# frozen_string_literal: true

class AddIdAggTypeIndexToBillableMetrics < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :billable_metrics,
        :id,
        name: :idx_billable_metrics_id_agg_type,
        include: [:aggregation_type],
        algorithm: :concurrently,
        if_not_exists: true
    end
  end
end
