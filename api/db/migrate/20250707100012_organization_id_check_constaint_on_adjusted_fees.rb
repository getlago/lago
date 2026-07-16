# frozen_string_literal: true

class OrganizationIdCheckConstaintOnAdjustedFees < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :adjusted_fees,
      "organization_id IS NOT NULL",
      name: "adjusted_fees_organization_id_not_null",
      validate: false
  end
end
