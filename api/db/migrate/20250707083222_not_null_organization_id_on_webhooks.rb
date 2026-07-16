# frozen_string_literal: true

class NotNullOrganizationIdOnWebhooks < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :webhooks, name: "webhooks_organization_id_null"
    change_column_null :webhooks, :organization_id, false
    remove_check_constraint :webhooks, name: "webhooks_organization_id_null"
  end

  def down
    add_check_constraint :webhooks, "organization_id IS NOT NULL", name: "webhooks_organization_id_null", validate: false
    change_column_null :webhooks, :organization_id, true
  end
end
