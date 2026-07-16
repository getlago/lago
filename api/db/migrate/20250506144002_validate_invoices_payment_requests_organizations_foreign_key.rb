# frozen_string_literal: true

class ValidateInvoicesPaymentRequestsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :invoices_payment_requests, :organizations
  end
end
