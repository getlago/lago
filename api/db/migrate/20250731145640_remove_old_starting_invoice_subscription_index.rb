# frozen_string_literal: true

class RemoveOldStartingInvoiceSubscriptionIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    if index_exists?(:invoice_subscriptions, nil, name: :index_unique_starting_subscription_invoice)
      remove_index :invoice_subscriptions, name: :index_unique_starting_subscription_invoice
    end
  end

  def down
    add_index :invoice_subscriptions,
      [:subscription_id, :invoicing_reason],
      unique: true,
      name: :index_unique_starting_subscription_invoice,
      where: "invoicing_reason = 'subscription_starting'",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
