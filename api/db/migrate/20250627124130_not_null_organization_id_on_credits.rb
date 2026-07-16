# frozen_string_literal: true

class NotNullOrganizationIdOnCredits < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :credits, name: "credits_organization_id_null"
    change_column_null :credits, :organization_id, false
    remove_check_constraint :credits, name: "credits_organization_id_null"
  end

  def down
    add_check_constraint :credits, "organization_id IS NOT NULL", name: "credits_organization_id_null", validate: false
    change_column_null :credits, :organization_id, true
  end
end
