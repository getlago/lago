# frozen_string_literal: true

class AddForeignKeyConstraintsToInvoicesBillingEntityId < ActiveRecord::Migration[7.2]
  def up
    # Add foreign key without validation first
    add_foreign_key :invoices, :billing_entities, validate: false
  end

  def down
    remove_foreign_key :invoices, :billing_entities
  end
end
