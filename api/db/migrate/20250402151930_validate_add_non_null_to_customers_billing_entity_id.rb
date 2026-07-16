# frozen_string_literal: true

class ValidateAddNonNullToCustomersBillingEntityId < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :customers, name: "customers_billing_entity_id_null"
    change_column_null :customers, :billing_entity_id, false
    remove_check_constraint :customers, name: "customers_billing_entity_id_null"
  end

  def down
    add_check_constraint :customers, "billing_entity_id IS NOT NULL", name: "customers_billing_entity_id_null", validate: false
    change_column_null :customers, :billing_entity_id, true
  end
end
