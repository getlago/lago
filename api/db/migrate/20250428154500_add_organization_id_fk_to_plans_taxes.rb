# frozen_string_literal: true

class AddOrganizationIdFkToPlansTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :plans_taxes, :organizations, validate: false
  end
end
