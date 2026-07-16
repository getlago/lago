# frozen_string_literal: true

class ValidateCustomerMetadataOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :customer_metadata, :organizations
  end
end
