# frozen_string_literal: true

class AddBillingEntityToIntegrationCollectionMappings < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :integration_collection_mappings,
      :billing_entity,
      type: :uuid,
      null: true,
      index: {algorithm: :concurrently}

    add_foreign_key :integration_collection_mappings, :billing_entities, on_delete: :cascade, validate: false
    add_index :integration_collection_mappings,
      [:mapping_type, :integration_id, :billing_entity_id],
      where: "billing_entity_id IS NOT NULL",
      unique: true,
      algorithm: :concurrently,
      name: "index_int_collection_mappings_unique_billing_entity_is_not_null"
    add_index :integration_collection_mappings,
      [:mapping_type, :integration_id, :organization_id],
      where: "billing_entity_id IS NULL",
      unique: true,
      algorithm: :concurrently,
      name: "index_int_collection_mappings_unique_billing_entity_is_null"
    remove_index :integration_collection_mappings, [:mapping_type, :integration_id], name: "index_int_collection_mappings_on_mapping_type_and_int_id"
  end
end
