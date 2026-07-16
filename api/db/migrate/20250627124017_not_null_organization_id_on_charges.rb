# frozen_string_literal: true

class NotNullOrganizationIdOnCharges < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :charges, name: "charges_organization_id_null"
    change_column_null :charges, :organization_id, false
    remove_check_constraint :charges, name: "charges_organization_id_null"
  end

  def down
    add_check_constraint :charges, "organization_id IS NOT NULL", name: "charges_organization_id_null", validate: false
    change_column_null :charges, :organization_id, true
  end
end
