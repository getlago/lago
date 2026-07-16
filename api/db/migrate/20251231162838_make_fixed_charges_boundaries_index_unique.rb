# frozen_string_literal: true

class MakeFixedChargesBoundariesIndexUnique < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Fix duplicates: nullify fixed_charges boundaries for all records that have duplicates
    # on (subscription_id, fixed_charges_from_datetime, fixed_charges_to_datetime).
    # We can do it because:
    # 1) we're introducing fixed charges and no invoices have fixed_charges yet,
    # 2) duplicates are happening because of charges billed monthly with yearly / semiannual subscriptions,
    #  which anyway should have nulls for fixed charges boundaries.
    # in total we now have 38 duplicates
    safety_assured do
      execute <<~SQL
        UPDATE invoice_subscriptions
        SET fixed_charges_from_datetime = NULL,
            fixed_charges_to_datetime = NULL
        WHERE (subscription_id, fixed_charges_from_datetime, fixed_charges_to_datetime) IN (
          SELECT subscription_id, fixed_charges_from_datetime, fixed_charges_to_datetime
          FROM invoice_subscriptions
          WHERE fixed_charges_from_datetime IS NOT NULL
            AND fixed_charges_to_datetime IS NOT NULL
            AND recurring = TRUE
            AND regenerated_invoice_id IS NULL
          GROUP BY subscription_id, fixed_charges_from_datetime, fixed_charges_to_datetime
          HAVING COUNT(*) > 1
        )
        AND recurring = TRUE
        AND regenerated_invoice_id IS NULL
      SQL
    end

    # Remove the existing non-unique index
    remove_index :invoice_subscriptions,
      name: :index_invoice_subscriptions_on_fixed_charges_boundaries,
      if_exists: true

    # Remove the unique index if it already exists (in case migration ran partially before)
    remove_index :invoice_subscriptions,
      name: :index_uniq_invoice_subscriptions_on_fixed_charges_boundaries,
      if_exists: true

    # Add unique index (only for non-NULL fixed_charges boundaries)
    add_index :invoice_subscriptions,
      [:subscription_id, :fixed_charges_from_datetime, :fixed_charges_to_datetime],
      unique: true,
      where: "fixed_charges_from_datetime IS NOT NULL AND recurring IS TRUE AND regenerated_invoice_id IS NULL",
      name: :index_uniq_invoice_subscriptions_on_fixed_charges_boundaries,
      algorithm: :concurrently
  end

  def down
    remove_index :invoice_subscriptions,
      name: :index_uniq_invoice_subscriptions_on_fixed_charges_boundaries,
      if_exists: true

    add_index :invoice_subscriptions,
      [:subscription_id, :fixed_charges_from_datetime, :fixed_charges_to_datetime],
      where: "recurring IS TRUE AND regenerated_invoice_id IS NULL",
      name: :index_invoice_subscriptions_on_fixed_charges_boundaries,
      algorithm: :concurrently
  end
end
