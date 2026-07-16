# frozen_string_literal: true

class NotNullOrganizationIdOnCommitments < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :commitments, name: "commitments_organization_id_null"
    change_column_null :commitments, :organization_id, false
    remove_check_constraint :commitments, name: "commitments_organization_id_null"
  end

  def down
    add_check_constraint :commitments, "organization_id IS NOT NULL", name: "commitments_organization_id_null", validate: false
    change_column_null :commitments, :organization_id, true
  end
end
