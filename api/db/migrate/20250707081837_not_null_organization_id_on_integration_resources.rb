# frozen_string_literal: true

class NotNullOrganizationIdOnIntegrationResources < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :integration_resources, name: "integration_resources_organization_id_null"
    change_column_null :integration_resources, :organization_id, false
    remove_check_constraint :integration_resources, name: "integration_resources_organization_id_null"
  end

  def down
    add_check_constraint :integration_resources, "organization_id IS NOT NULL", name: "integration_resources_organization_id_null", validate: false
    change_column_null :integration_resources, :organization_id, true
  end
end
