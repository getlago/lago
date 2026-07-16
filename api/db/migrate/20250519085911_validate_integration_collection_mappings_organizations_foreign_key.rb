# frozen_string_literal: true

class ValidateIntegrationCollectionMappingsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :integration_collection_mappings, :organizations
  end
end
