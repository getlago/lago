# frozen_string_literal: true

class FixInvoicesWithIncorrectTotalPaidAmount < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def up
    safety_assured do
      execute <<~SQL
        UPDATE invoices
        SET total_paid_amount_cents = 0
        WHERE id IN (
            SELECT invoices.id
            FROM invoices
            LEFT JOIN payments ON invoices.id = payments.payable_id
            LEFT JOIN invoices_payment_requests ON invoices.id = invoices_payment_requests.invoice_id
            WHERE payments.id IS NULL 
            AND invoices_payment_requests.id IS NULL
            AND total_amount_cents > 0
            AND invoice_type <> 4
            AND total_amount_cents = total_paid_amount_cents  
            AND payment_status = 1
        );
      SQL
    end
  end

  def down
  end
end
