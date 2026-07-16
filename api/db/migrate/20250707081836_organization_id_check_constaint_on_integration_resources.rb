# frozen_string_literal: true

class OrganizationIdCheckConstaintOnIntegrationResources < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :integration_resources,
      "organization_id IS NOT NULL",
      name: "integration_resources_organization_id_null",
      validate: false
  end
end
