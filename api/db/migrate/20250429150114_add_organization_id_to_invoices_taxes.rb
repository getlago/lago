# frozen_string_literal: true

class AddOrganizationIdToInvoicesTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :invoices_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
