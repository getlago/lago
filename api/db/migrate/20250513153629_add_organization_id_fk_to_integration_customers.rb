# frozen_string_literal: true

class AddOrganizationIdFkToIntegrationCustomers < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :integration_customers, :organizations, validate: false
  end
end
