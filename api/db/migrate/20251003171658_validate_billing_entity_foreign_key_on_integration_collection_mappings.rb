# frozen_string_literal: true

class ValidateBillingEntityForeignKeyOnIntegrationCollectionMappings < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :integration_collection_mappings, :billing_entities
  end
end
