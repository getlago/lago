# frozen_string_literal: true

class AddScopedIndexToStartingInvoiceSubscription < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoice_subscriptions,
      [:subscription_id, :invoicing_reason],
      unique: true,
      name: :index_unique_starting_invoice_subscription,
      where: "invoicing_reason = 'subscription_starting' AND regenerated_invoice_id IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
