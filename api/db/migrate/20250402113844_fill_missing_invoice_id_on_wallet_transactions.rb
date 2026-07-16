# frozen_string_literal: true

class FillMissingInvoiceIdOnWalletTransactions < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE wallet_transactions wt
        SET invoice_id = (
                SELECT f.invoice_id
                FROM fees f
                WHERE f.invoiceable_id = wt.id
                      AND f.invoiceable_type = 'WalletTransaction'
                      AND f.invoice_id IS NOT null
                LIMIT 1
            )
        WHERE wt.invoice_id IS null;
      SQL
    end
  end

  def down
    # no action needed
  end
end
