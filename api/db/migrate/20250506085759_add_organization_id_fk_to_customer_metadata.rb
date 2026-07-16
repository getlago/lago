# frozen_string_literal: true

class AddOrganizationIdFkToCustomerMetadata < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :customer_metadata, :organizations, validate: false
  end
end
