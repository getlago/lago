# frozen_string_literal: true

class OrganizationIdCheckConstaintOnFeesTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :fees_taxes,
      "organization_id IS NOT NULL",
      name: "fees_taxes_organization_id_null",
      validate: false
  end
end
