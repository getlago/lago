# frozen_string_literal: true

class AddScopedIndexToChargesFromAndToDatetime < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoice_subscriptions,
      [:subscription_id, :charges_from_datetime, :charges_to_datetime],
      unique: true,
      name: :index_uniq_invoice_subscriptions_on_charges_from_to_datetime,
      where: "created_at >= '2023-06-09 00:00:00' AND recurring IS TRUE AND regenerated_invoice_id IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
