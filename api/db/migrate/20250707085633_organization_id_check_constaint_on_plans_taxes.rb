# frozen_string_literal: true

class OrganizationIdCheckConstaintOnPlansTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :plans_taxes,
      "organization_id IS NOT NULL",
      name: "plans_taxes_organization_id_null",
      validate: false
  end
end
