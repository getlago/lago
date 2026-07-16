# frozen_string_literal: true

class AddOrganizationIdFkToIntegrationItems < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :integration_items, :organizations, validate: false
  end
end
