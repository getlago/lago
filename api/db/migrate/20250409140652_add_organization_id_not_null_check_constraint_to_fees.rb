# frozen_string_literal: true

class AddOrganizationIdNotNullCheckConstraintToFees < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :fees, "organization_id IS NOT NULL", name: "fees_organization_id_null", validate: false
  end
end
