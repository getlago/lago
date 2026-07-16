# frozen_string_literal: true

class NotNullOrganizationIdOnDataExports < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :data_exports, name: "data_exports_organization_id_null"
    change_column_null :data_exports, :organization_id, false
    remove_check_constraint :data_exports, name: "data_exports_organization_id_null"
  end

  def down
    add_check_constraint :data_exports, "organization_id IS NOT NULL", name: "data_exports_organization_id_null", validate: false
    change_column_null :data_exports, :organization_id, true
  end
end
