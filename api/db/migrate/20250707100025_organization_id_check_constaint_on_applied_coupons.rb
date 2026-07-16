# frozen_string_literal: true

class OrganizationIdCheckConstaintOnAppliedCoupons < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :applied_coupons,
      "organization_id IS NOT NULL",
      name: "applied_coupons_organization_id_not_null",
      validate: false
  end
end
