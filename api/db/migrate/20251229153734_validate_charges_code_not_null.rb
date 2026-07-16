# frozen_string_literal: true

class ValidateChargesCodeNotNull < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    validate_check_constraint :charges, name: "charges_code_not_null"
    change_column_null :charges, :code, false
    remove_check_constraint :charges, name: "charges_code_not_null"

    validate_check_constraint :fixed_charges, name: "fixed_charges_code_not_null"
    change_column_null :fixed_charges, :code, false
    remove_check_constraint :fixed_charges, name: "fixed_charges_code_not_null"
  end
end
