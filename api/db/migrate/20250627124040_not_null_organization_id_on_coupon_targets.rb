# frozen_string_literal: true

class NotNullOrganizationIdOnCouponTargets < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :coupon_targets, name: "coupon_targets_organization_id_null"
    change_column_null :coupon_targets, :organization_id, false
    remove_check_constraint :coupon_targets, name: "coupon_targets_organization_id_null"
  end

  def down
    add_check_constraint :coupon_targets, "organization_id IS NOT NULL", name: "coupon_targets_organization_id_null", validate: false
    change_column_null :coupon_targets, :organization_id, true
  end
end
