# frozen_string_literal: true

class NotNullOrganizationIdOnPayments < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :payments, name: "payments_organization_id_null"
    change_column_null :payments, :organization_id, false
    remove_check_constraint :payments, name: "payments_organization_id_null"
  end

  def down
    add_check_constraint :payments, "organization_id IS NOT NULL", name: "payments_organization_id_null", validate: false
    change_column_null :payments, :organization_id, true
  end
end
