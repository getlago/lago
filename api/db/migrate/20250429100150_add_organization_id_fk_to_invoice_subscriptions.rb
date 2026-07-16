# frozen_string_literal: true

class AddOrganizationIdFkToInvoiceSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :invoice_subscriptions, :organizations, validate: false
  end
end
