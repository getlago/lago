# frozen_string_literal: true

class OrganizationIdCheckConstaintOnPayments < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :payments,
      "organization_id IS NOT NULL",
      name: "payments_organization_id_null",
      validate: false
  end
end
