# frozen_string_literal: true

class RemoveOldScopedChargesFromToDatetimeIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    if index_exists?(:invoice_subscriptions, [:subscription_id, :charges_from_datetime, :charges_to_datetime], name: :index_invoice_subscriptions_on_charges_from_and_to_datetime)
      remove_index :invoice_subscriptions, name: :index_invoice_subscriptions_on_charges_from_and_to_datetime
    end
  end

  def down
    add_index :invoice_subscriptions,
      [:subscription_id, :charges_from_datetime, :charges_to_datetime],
      unique: true,
      name: :index_invoice_subscriptions_on_charges_from_and_to_datetime,
      where: "created_at >= '2023-06-09 00:00:00' AND recurring IS TRUE",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
