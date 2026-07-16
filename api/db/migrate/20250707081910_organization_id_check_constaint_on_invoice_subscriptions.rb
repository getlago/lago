# frozen_string_literal: true

class OrganizationIdCheckConstaintOnInvoiceSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :invoice_subscriptions,
      "organization_id IS NOT NULL",
      name: "invoice_subscriptions_organization_id_null",
      validate: false
  end
end
