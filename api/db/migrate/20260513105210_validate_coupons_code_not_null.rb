# frozen_string_literal: true

class ValidateCouponsCodeNotNull < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :coupons, name: "coupons_code_not_null"
    change_column_null :coupons, :code, false
    remove_check_constraint :coupons, name: "coupons_code_not_null"
  end

  def down
    add_check_constraint :coupons, "code IS NOT NULL", name: "coupons_code_not_null", validate: false
    change_column_null :coupons, :code, true
  end
end
