# frozen_string_literal: true

class AddOrganizationIdFkToBillingEntitiesTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :billing_entities_taxes, :organizations, validate: false
  end
end
