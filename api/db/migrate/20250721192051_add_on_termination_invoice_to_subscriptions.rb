# frozen_string_literal: true

class AddOnTerminationInvoiceToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_enum(
      :subscription_on_termination_invoice,
      %w[generate skip]
    )
    add_column(
      :subscriptions,
      :on_termination_invoice,
      :enum,
      enum_type: "subscription_on_termination_invoice",
      default: "generate",
      null: false
    )
  end
end
