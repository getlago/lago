# frozen_string_literal: true

class NotNullOrganizationIdOnIntegrationMappings < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :integration_mappings, name: "integration_mappings_organization_id_not_null"
    change_column_null :integration_mappings, :organization_id, false
    remove_check_constraint :integration_mappings, name: "integration_mappings_organization_id_not_null"
  end

  def down
    add_check_constraint :integration_mappings, "organization_id IS NOT NULL", name: "integration_mappings_organization_id_not_null", validate: false
    change_column_null :integration_mappings, :organization_id, true
  end
end
