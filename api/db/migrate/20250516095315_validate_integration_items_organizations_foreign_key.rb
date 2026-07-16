# frozen_string_literal: true

class ValidateIntegrationItemsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :integration_items, :organizations
  end
end
