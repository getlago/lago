# frozen_string_literal: true

class AddOrganizationIdFkToInvoicesPaymentRequests < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :invoices_payment_requests, :organizations, validate: false
  end
end
