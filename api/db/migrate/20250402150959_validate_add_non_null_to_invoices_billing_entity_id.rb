# frozen_string_literal: true

class ValidateAddNonNullToInvoicesBillingEntityId < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :invoices, name: "invoices_billing_entity_id_null"
    change_column_null :invoices, :billing_entity_id, false
    remove_check_constraint :invoices, name: "invoices_billing_entity_id_null"
  end

  def down
    add_check_constraint :invoices, "billing_entity_id IS NOT NULL", name: "invoices_billing_entity_id_null", validate: false
    change_column_null :invoices, :billing_entity_id, true
  end
end
