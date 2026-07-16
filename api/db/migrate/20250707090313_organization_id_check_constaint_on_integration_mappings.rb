# frozen_string_literal: true

class OrganizationIdCheckConstaintOnIntegrationMappings < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :integration_mappings,
      "organization_id IS NOT NULL",
      name: "integration_mappings_organization_id_not_null",
      validate: false
  end
end
