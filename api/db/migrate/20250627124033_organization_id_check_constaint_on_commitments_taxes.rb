# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCommitmentsTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :commitments_taxes,
      "organization_id IS NOT NULL",
      name: "commitments_taxes_organization_id_null",
      validate: false
  end
end
