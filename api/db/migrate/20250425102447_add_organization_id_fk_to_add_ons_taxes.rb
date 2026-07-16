# frozen_string_literal: true

class AddOrganizationIdFkToAddOnsTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :add_ons_taxes, :organizations, validate: false
  end
end
