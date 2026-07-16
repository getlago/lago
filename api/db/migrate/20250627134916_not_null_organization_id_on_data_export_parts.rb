# frozen_string_literal: true

class NotNullOrganizationIdOnDataExportParts < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :data_export_parts, name: "data_export_parts_organization_id_null"
    change_column_null :data_export_parts, :organization_id, false
    remove_check_constraint :data_export_parts, name: "data_export_parts_organization_id_null"
  end

  def down
    add_check_constraint :data_export_parts, "organization_id IS NOT NULL", name: "data_export_parts_organization_id_null", validate: false
    change_column_null :data_export_parts, :organization_id, true
  end
end
