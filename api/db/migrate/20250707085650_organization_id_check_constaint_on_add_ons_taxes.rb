# frozen_string_literal: true

class OrganizationIdCheckConstaintOnAddOnsTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :add_ons_taxes,
      "organization_id IS NOT NULL",
      name: "add_ons_taxes_organization_id_null",
      validate: false
  end
end
