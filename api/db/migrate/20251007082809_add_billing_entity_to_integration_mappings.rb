# frozen_string_literal: true

class AddBillingEntityToIntegrationMappings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :integration_mappings, :billing_entity_id, :uuid, null: true

    add_foreign_key :integration_mappings, :billing_entities, on_delete: :cascade, validate: false

    # Add unique indexes for billing entity mappings and organization-wide mappings
    add_index :integration_mappings, [:mappable_type, :mappable_id, :integration_id, :billing_entity_id],
      where: "billing_entity_id IS NOT NULL",
      unique: true,
      algorithm: :concurrently,
      name: "index_integration_mappings_unique_billing_entity_id_is_not_null"

    add_index :integration_mappings, [:mappable_type, :mappable_id, :integration_id, :organization_id],
      where: "billing_entity_id IS NULL",
      unique: true,
      algorithm: :concurrently,
      name: "index_integration_mappings_unique_billing_entity_id_is_null"
  end
end
