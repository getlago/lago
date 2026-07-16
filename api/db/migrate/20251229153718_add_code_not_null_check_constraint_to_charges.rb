# frozen_string_literal: true

class AddCodeNotNullCheckConstraintToCharges < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :charges, "code IS NOT NULL", name: "charges_code_not_null", validate: false, if_not_exists: true
    add_check_constraint :fixed_charges, "code IS NOT NULL", name: "fixed_charges_code_not_null", validate: false, if_not_exists: true
  end
end
