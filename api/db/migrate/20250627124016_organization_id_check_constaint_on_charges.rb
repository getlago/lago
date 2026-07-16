# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCharges < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :charges,
      "organization_id IS NOT NULL",
      name: "charges_organization_id_null",
      validate: false
  end
end
