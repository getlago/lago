# frozen_string_literal: true

class OrganizationIdCheckConstaintOnRefunds < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :refunds,
      "organization_id IS NOT NULL",
      name: "refunds_organization_id_null",
      validate: false
  end
end
