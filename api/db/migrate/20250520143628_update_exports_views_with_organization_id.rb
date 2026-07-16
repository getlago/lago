# frozen_string_literal: true

class UpdateExportsViewsWithOrganizationId < ActiveRecord::Migration[8.0]
  def change
    update_view :exports_applied_coupons, version: 2, revert_to_version: 1
    update_view :exports_charges, version: 2, revert_to_version: 1
    update_view :exports_credit_notes_taxes, version: 2, revert_to_version: 1
    update_view :exports_credit_notes, version: 2, revert_to_version: 1
    update_view :exports_fees_taxes, version: 2, revert_to_version: 1
    update_view :exports_invoices_taxes, version: 2, revert_to_version: 1
    update_view :exports_subscriptions, version: 2, revert_to_version: 1
    update_view :exports_wallet_transactions, version: 2, revert_to_version: 1
    update_view :exports_wallets, version: 2, revert_to_version: 1
  end
end
