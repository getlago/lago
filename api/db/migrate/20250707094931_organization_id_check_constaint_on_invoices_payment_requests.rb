# frozen_string_literal: true

class OrganizationIdCheckConstaintOnInvoicesPaymentRequests < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :invoices_payment_requests,
      "organization_id IS NOT NULL",
      name: "invoices_payment_requests_organization_id_not_null",
      validate: false
  end
end
