# frozen_string_literal: true

class ValidateAddNonNullToFeesOrganizationId < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :fees, name: "fees_organization_id_null"
    change_column_null :fees, :organization_id, false
    remove_check_constraint :fees, name: "fees_organization_id_null"
  end

  def down
    add_check_constraint :fees, "organization_id IS NOT NULL", name: "fees_organization_id_null", validate: false
  end
end
