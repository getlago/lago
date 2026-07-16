# frozen_string_literal: true

class ValidateBillingEntityForeignKeyOnIntegrationMappings < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :integration_mappings, :billing_entities
  end
end
