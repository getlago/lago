# frozen_string_literal: true

class OrganizationIdCheckConstaintOnBillingEntitiesTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :billing_entities_taxes,
      "organization_id IS NOT NULL",
      name: "billing_entities_taxes_organization_id_null",
      validate: false
  end
end
