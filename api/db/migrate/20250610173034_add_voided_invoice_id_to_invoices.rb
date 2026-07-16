# frozen_string_literal: true

class AddVoidedInvoiceIdToInvoices < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :invoices, :voided_invoice, type: :uuid, index: {algorithm: :concurrently}
  end
end
