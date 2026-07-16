# frozen_string_literal: true

class AddSubscriptionInvoiceIssuingDateAnchorAndAdjustmentToBillingEntity < ActiveRecord::Migration[8.0]
  def change
    create_enum :subscription_invoice_issuing_date_anchors, %w[current_period_end next_period_start]
    create_enum :subscription_invoice_issuing_date_adjustments, %w[keep_anchor align_with_finalization_date]

    add_column :billing_entities,
      :subscription_invoice_issuing_date_anchor,
      :enum,
      enum_type: :subscription_invoice_issuing_date_anchors,
      default: "next_period_start",
      null: false

    add_column :billing_entities,
      :subscription_invoice_issuing_date_adjustment,
      :enum,
      enum_type: :subscription_invoice_issuing_date_adjustments,
      default: "align_with_finalization_date",
      null: false
  end
end
