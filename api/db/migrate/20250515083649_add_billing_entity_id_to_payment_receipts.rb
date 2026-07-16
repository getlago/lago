# frozen_string_literal: true

class AddBillingEntityIdToPaymentReceipts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :payment_receipts, :billing_entity, type: :uuid, null: true, index: {algorithm: :concurrently}
  end
end
