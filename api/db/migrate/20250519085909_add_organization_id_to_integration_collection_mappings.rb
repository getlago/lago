# frozen_string_literal: true

class AddOrganizationIdToIntegrationCollectionMappings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :integration_collection_mappings, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
