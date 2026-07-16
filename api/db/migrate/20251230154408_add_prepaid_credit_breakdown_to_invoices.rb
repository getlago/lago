# frozen_string_literal: true

class AddPrepaidCreditBreakdownToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :prepaid_granted_credit_amount_cents, :bigint
    add_column :invoices, :prepaid_purchased_credit_amount_cents, :bigint
  end
end
