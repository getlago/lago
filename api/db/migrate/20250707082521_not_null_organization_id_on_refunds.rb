# frozen_string_literal: true

class NotNullOrganizationIdOnRefunds < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :refunds, name: "refunds_organization_id_null"
    change_column_null :refunds, :organization_id, false
    remove_check_constraint :refunds, name: "refunds_organization_id_null"
  end

  def down
    add_check_constraint :refunds, "organization_id IS NOT NULL", name: "refunds_organization_id_null", validate: false
    change_column_null :refunds, :organization_id, true
  end
end
