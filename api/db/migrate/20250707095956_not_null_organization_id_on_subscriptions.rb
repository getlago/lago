# frozen_string_literal: true

class NotNullOrganizationIdOnSubscriptions < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :subscriptions, name: "subscriptions_organization_id_not_null"
    change_column_null :subscriptions, :organization_id, false
    remove_check_constraint :subscriptions, name: "subscriptions_organization_id_not_null"
  end

  def down
    add_check_constraint :subscriptions, "organization_id IS NOT NULL", name: "subscriptions_organization_id_not_null", validate: false
    change_column_null :subscriptions, :organization_id, true
  end
end
