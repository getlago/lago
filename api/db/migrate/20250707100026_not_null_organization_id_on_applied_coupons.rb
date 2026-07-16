# frozen_string_literal: true

class NotNullOrganizationIdOnAppliedCoupons < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :applied_coupons, name: "applied_coupons_organization_id_not_null"
    change_column_null :applied_coupons, :organization_id, false
    remove_check_constraint :applied_coupons, name: "applied_coupons_organization_id_not_null"
  end

  def down
    add_check_constraint :applied_coupons, "organization_id IS NOT NULL", name: "applied_coupons_organization_id_not_null", validate: false
    change_column_null :applied_coupons, :organization_id, true
  end
end
