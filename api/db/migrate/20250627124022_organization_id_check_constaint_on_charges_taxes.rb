# frozen_string_literal: true

class OrganizationIdCheckConstaintOnChargesTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :charges_taxes,
      "organization_id IS NOT NULL",
      name: "charges_taxes_organization_id_null",
      validate: false
  end
end
