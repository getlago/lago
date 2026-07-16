# frozen_string_literal: true

class AddRegeneratedInvoiceIdAndIndexToInvoiceSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :invoice_subscriptions,
      :regenerated_invoice,
      index: {algorithm: :concurrently},
      type: :uuid

    add_index :invoice_subscriptions,
      [:subscription_id, :invoicing_reason],
      unique: true,
      name: :index_unique_terminating_invoice_subscription,
      where: "invoicing_reason = 'subscription_terminating' AND regenerated_invoice_id IS NULL",
      algorithm: :concurrently
  end
end
