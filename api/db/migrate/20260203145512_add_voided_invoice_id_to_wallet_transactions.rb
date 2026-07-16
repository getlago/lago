# frozen_string_literal: true

class AddVoidedInvoiceIdToWalletTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :wallet_transactions,
      :voided_invoice,
      type: :uuid,
      index: {algorithm: :concurrently}
  end
end
