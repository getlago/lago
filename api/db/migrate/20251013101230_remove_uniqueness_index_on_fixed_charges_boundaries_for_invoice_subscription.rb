# frozen_string_literal: true

class RemoveUniquenessIndexOnFixedChargesBoundariesForInvoiceSubscription < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!
  def up
    safety_assured do
      remove_index :invoice_subscriptions, name: :index_uniq_invoice_subscriptions_on_fixed_charges_boundaries
      add_index :invoice_subscriptions,
        [:subscription_id, :fixed_charges_from_datetime, :fixed_charges_to_datetime],
        name: :index_invoice_subscriptions_on_fixed_charges_boundaries,
        where: "recurring IS TRUE AND regenerated_invoice_id IS NULL",
        algorithm: :concurrently
    end
  end
end
