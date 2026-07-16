# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCouponTargets < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :coupon_targets,
      "organization_id IS NOT NULL",
      name: "coupon_targets_organization_id_null",
      validate: false
  end
end
