# frozen_string_literal: true

class CreateCustomersExportView < ActiveRecord::Migration[7.0]
  def change
    create_view :exports_customers, version: 1
    create_view :exports_billable_metrics, version: 1
    create_view :exports_plans, version: 1
    create_view :exports_applied_coupons, version: 1
    create_view :exports_invoices, version: 1
    create_view :exports_invoices_taxes, version: 1
    create_view :exports_charges, version: 1
    create_view :exports_wallets, version: 1
    create_view :exports_wallet_transactions, version: 1
    create_view :exports_coupons, version: 1
    create_view :exports_taxes, version: 1
    create_view :exports_credit_notes_taxes, version: 1
    create_view :exports_credit_notes, version: 1
    create_view :exports_fees_taxes, version: 1
    create_view :exports_fees, version: 1
    create_view :exports_subscriptions, version: 1
  end
end
