# frozen_string_literal: true

class NotNullOrganizationIdOnCustomerMetadata < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :customer_metadata, name: "customer_metadata_organization_id_null"
    change_column_null :customer_metadata, :organization_id, false
    remove_check_constraint :customer_metadata, name: "customer_metadata_organization_id_null"
  end

  def down
    add_check_constraint :customer_metadata, "organization_id IS NOT NULL", name: "customer_metadata_organization_id_null", validate: false
    change_column_null :customer_metadata, :organization_id, true
  end
end
