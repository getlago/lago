# frozen_string_literal: true

class OrganizationIdCheckConstaintOnIntegrationCollectionMappings < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :integration_collection_mappings,
      "organization_id IS NOT NULL",
      name: "integration_collection_mappings_organization_id_not_null",
      validate: false
  end
end
