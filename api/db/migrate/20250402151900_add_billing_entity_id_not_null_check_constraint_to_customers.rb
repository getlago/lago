# frozen_string_literal: true

class AddBillingEntityIdNotNullCheckConstraintToCustomers < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :customers, "billing_entity_id IS NOT NULL", name: "customers_billing_entity_id_null", validate: false
  end
end
