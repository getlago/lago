# frozen_string_literal: true

class OrganizationIdCheckConstaintOnIntegrationItems < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :integration_items,
      "organization_id IS NOT NULL",
      name: "integration_items_organization_id_null",
      validate: false
  end
end
