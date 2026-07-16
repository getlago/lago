# frozen_string_literal: true

class AddOrganizationIdFkToIntegrationCollectionMappings < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :integration_collection_mappings, :organizations, validate: false
  end
end
