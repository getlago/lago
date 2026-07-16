# frozen_string_literal: true

class AddOrganizationIdFkToChargesTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :charges_taxes, :organizations, validate: false
  end
end
