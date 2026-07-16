# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCustomerMetadata < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :customer_metadata,
      "organization_id IS NOT NULL",
      name: "customer_metadata_organization_id_null",
      validate: false
  end
end
