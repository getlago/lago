# frozen_string_literal: true

class ValidateIntegrationCustomersOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :integration_customers, :organizations
  end
end
