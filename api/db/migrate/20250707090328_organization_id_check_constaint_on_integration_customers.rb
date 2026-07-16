# frozen_string_literal: true

class OrganizationIdCheckConstaintOnIntegrationCustomers < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :integration_customers,
      "organization_id IS NOT NULL",
      name: "integration_customers_organization_id_not_null",
      validate: false
  end
end
