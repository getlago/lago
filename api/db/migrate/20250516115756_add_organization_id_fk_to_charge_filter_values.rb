# frozen_string_literal: true

class AddOrganizationIdFkToChargeFilterValues < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :charge_filter_values, :organizations, validate: false
  end
end
