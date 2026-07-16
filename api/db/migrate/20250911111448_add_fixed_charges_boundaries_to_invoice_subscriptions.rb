# frozen_string_literal: true

class AddFixedChargesBoundariesToInvoiceSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :invoice_subscriptions, :fixed_charges_from_datetime, :datetime
    add_column :invoice_subscriptions, :fixed_charges_to_datetime, :datetime

    add_index(
      :invoice_subscriptions,
      %i[
        subscription_id
        fixed_charges_from_datetime
        fixed_charges_to_datetime
      ],
      unique: true,
      name: :index_uniq_invoice_subscriptions_on_fixed_charges_boundaries,
      where: "recurring IS TRUE AND regenerated_invoice_id IS NULL",
      algorithm: :concurrently
    )
  end
end
