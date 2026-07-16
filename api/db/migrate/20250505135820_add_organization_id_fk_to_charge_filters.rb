# frozen_string_literal: true

class AddOrganizationIdFkToChargeFilters < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :charge_filters, :organizations, validate: false
  end
end
