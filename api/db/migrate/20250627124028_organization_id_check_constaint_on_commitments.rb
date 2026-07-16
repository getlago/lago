# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCommitments < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :commitments,
      "organization_id IS NOT NULL",
      name: "commitments_organization_id_null",
      validate: false
  end
end
