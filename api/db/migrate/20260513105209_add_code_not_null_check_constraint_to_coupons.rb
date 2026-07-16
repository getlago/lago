# frozen_string_literal: true

class AddCodeNotNullCheckConstraintToCoupons < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :coupons, "code IS NOT NULL",
      name: "coupons_code_not_null", validate: false, if_not_exists: true
  end
end
