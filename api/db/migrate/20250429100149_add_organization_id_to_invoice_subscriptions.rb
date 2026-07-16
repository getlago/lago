# frozen_string_literal: true

class AddOrganizationIdToInvoiceSubscriptions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :invoice_subscriptions, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
