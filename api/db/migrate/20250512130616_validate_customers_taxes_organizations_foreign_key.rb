# frozen_string_literal: true

class ValidateCustomersTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :customers_taxes, :organizations
  end
end
