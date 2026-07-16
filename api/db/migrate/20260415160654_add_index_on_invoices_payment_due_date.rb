# frozen_string_literal: true

class AddIndexOnInvoicesPaymentDueDate < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :invoices, :payment_due_date,
      where: "status = 1
              AND payment_status <> 1
              AND payment_overdue = false
              AND payment_dispute_lost_at IS NULL",
      name: :index_invoices_on_payment_due_date,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
