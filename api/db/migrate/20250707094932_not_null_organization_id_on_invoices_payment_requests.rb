# frozen_string_literal: true

class NotNullOrganizationIdOnInvoicesPaymentRequests < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :invoices_payment_requests, name: "invoices_payment_requests_organization_id_not_null"
    change_column_null :invoices_payment_requests, :organization_id, false
    remove_check_constraint :invoices_payment_requests, name: "invoices_payment_requests_organization_id_not_null"
  end

  def down
    add_check_constraint :invoices_payment_requests, "organization_id IS NOT NULL", name: "invoices_payment_requests_organization_id_not_null", validate: false
    change_column_null :invoices_payment_requests, :organization_id, true
  end
end
