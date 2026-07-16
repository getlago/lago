# frozen_string_literal: true

class AddPlanBmProratedIndexToCharges < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :charges,
        [:plan_id, :billable_metric_id, :prorated],
        name: :index_charges_on_plan_id_and_billable_metric_id_and_prorated,
        where: "deleted_at IS NULL",
        algorithm: :concurrently,
        if_not_exists: true
    end
  end
end
