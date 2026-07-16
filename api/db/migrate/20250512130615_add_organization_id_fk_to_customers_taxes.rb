# frozen_string_literal: true

class AddOrganizationIdFkToCustomersTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :customers_taxes, :organizations, validate: false
  end
end
