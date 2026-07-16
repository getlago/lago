# frozen_string_literal: true

class AddReferencesToBillingEntities < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_reference :billing_entities, :applied_dunning_campaign, index: {algorithm: :concurrently}, type: :uuid

    add_reference :customers, :billing_entity, index: {algorithm: :concurrently}, type: :uuid
    add_reference :invoices, :billing_entity, index: {algorithm: :concurrently}, type: :uuid
    add_reference :invoice_custom_section_selections, :billing_entity, index: {algorithm: :concurrently}, type: :uuid
    add_reference :fees, :billing_entity, index: {algorithm: :concurrently}, type: :uuid

    # will be populated with the part to create billing_entities
    add_column :invoices, :billing_entity_sequential_id, :integer, default: 0

    add_index :invoices, [:organization_id, :billing_entity_sequential_id],
      order: {billing_entity_sequential_id: :desc},
      algorithm: :concurrently,
      if_not_exists: true,
      include: %i[self_billed]
  end
end
