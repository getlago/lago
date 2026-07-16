# frozen_string_literal: true

class AddCodeToCharges < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :charges, :code, :string
    add_column :fixed_charges, :code, :string

    add_index :charges,
      [:plan_id, :code],
      unique: true,
      where: "deleted_at IS NULL AND parent_id IS NULL",
      name: "index_charges_on_plan_id_and_code",
      algorithm: :concurrently

    add_index :fixed_charges,
      [:plan_id, :code],
      unique: true,
      where: "deleted_at IS NULL AND parent_id IS NULL",
      name: "index_fixed_charges_on_plan_id_and_code",
      algorithm: :concurrently
  end
end
