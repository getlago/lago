# frozen_string_literal: true

class AddOrganizationIdFkToIntegrationMappings < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :integration_mappings, :organizations, validate: false
  end
end
