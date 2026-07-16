# frozen_string_literal: true

class OrganizationIdCheckConstaintOnChargeFilterValues < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :charge_filter_values,
      "organization_id IS NOT NULL",
      name: "charge_filter_values_organization_id_null",
      validate: false
  end
end
