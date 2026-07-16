# frozen_string_literal: true

class AddBillingEntityIdNotNullCheckConstraint < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :invoices, "billing_entity_id IS NOT NULL", name: "invoices_billing_entity_id_null", validate: false
  end
end
