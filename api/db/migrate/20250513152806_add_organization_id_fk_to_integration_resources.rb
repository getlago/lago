# frozen_string_literal: true

class AddOrganizationIdFkToIntegrationResources < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :integration_resources, :organizations, validate: false
  end
end
