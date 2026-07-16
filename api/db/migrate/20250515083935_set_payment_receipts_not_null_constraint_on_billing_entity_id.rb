# frozen_string_literal: true

class SetPaymentReceiptsNotNullConstraintOnBillingEntityId < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :payment_receipts, "billing_entity_id IS NOT NULL", name: "payment_receipts_billing_entity_id_null", validate: false
  end
end
