# frozen_string_literal: true

class OrganizationIdCheckConstaintOnChargeFilters < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :charge_filters,
      "organization_id IS NOT NULL",
      name: "charge_filters_organization_id_null",
      validate: false
  end
end
