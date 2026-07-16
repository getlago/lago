# frozen_string_literal: true

class AddSubscriptionInvoiceIssuingDateAnchorAndAdjustmentsToCustomer < ActiveRecord::Migration[8.0]
  def change
    add_column :customers,
      :subscription_invoice_issuing_date_anchor,
      :enum,
      enum_type: :subscription_invoice_issuing_date_anchors,
      null: true

    add_column :customers,
      :subscription_invoice_issuing_date_adjustment,
      :enum,
      enum_type: :subscription_invoice_issuing_date_adjustments,
      null: true
  end
end
