# frozen_string_literal: true

class MarkPendingWalletTransactionsAsFailed < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    # Update transactions using the latest `updated_at` from failed payments (if available)
    safety_assured do
      execute <<~SQL.squish
        UPDATE wallet_transactions wt
        SET status = 2,
            failed_at = (
                SELECT MAX(p.updated_at)
                FROM fees f
                INNER JOIN invoices i ON i.id = f.invoice_id
                INNER JOIN payments p ON p.payable_id = i.id
                WHERE f.invoiceable_id = wt.id
                  AND f.invoiceable_type = 'WalletTransaction'
                  AND i.payment_status = 2
                  AND p.payable_payment_status = 'failed'
            )
        WHERE wt.status = 0
          AND EXISTS (
                SELECT 1
                FROM fees f
                INNER JOIN invoices i ON i.id = f.invoice_id
                INNER JOIN payments p ON p.payable_id = i.id
                WHERE f.invoiceable_id = wt.id
                  AND f.invoiceable_type = 'WalletTransaction'
                  AND i.payment_status = 2
                  AND p.payable_payment_status = 'failed'
            );
      SQL
    end

    # Then update transactions using `invoices.updated_at` if no failed payment exists
    safety_assured do
      execute <<~SQL.squish
        UPDATE wallet_transactions wt
        SET status = 2,
            failed_at = (
                SELECT MAX(i.updated_at)
                FROM fees f
                INNER JOIN invoices i ON i.id = f.invoice_id
                WHERE f.invoiceable_id = wt.id
                  AND f.invoiceable_type = 'WalletTransaction'
                  AND i.payment_status = 2
                  AND NOT EXISTS (
                      SELECT 1
                      FROM payments p
                      WHERE p.payable_id = i.id
                  )
            )
        WHERE wt.status = 0
          AND EXISTS (
              SELECT 1
              FROM fees f
              INNER JOIN invoices i ON i.id = f.invoice_id
              WHERE f.invoiceable_id = wt.id
                AND f.invoiceable_type = 'WalletTransaction'
                AND i.payment_status = 2
                AND NOT EXISTS (
                    SELECT 1
                    FROM payments p
                    WHERE p.payable_id = i.id
                )
          );
      SQL
    end
  end

  def down
    # do nothing
  end
end
