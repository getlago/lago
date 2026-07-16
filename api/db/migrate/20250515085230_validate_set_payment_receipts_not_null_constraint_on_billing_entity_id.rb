# frozen_string_literal: true

class ValidateSetPaymentReceiptsNotNullConstraintOnBillingEntityId < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :payment_receipts, name: "payment_receipts_billing_entity_id_null"
    change_column_null :payment_receipts, :billing_entity_id, false
    remove_check_constraint :payment_receipts, name: "payment_receipts_billing_entity_id_null"
  end

  def down
    add_check_constraint :payment_receipts, "billing_entity_id IS NOT NULL", name: "payment_receipts_billing_entity_id_null", validate: false
    change_column_null :payment_receipts, :billing_entity_id, true
  end
end
