# frozen_string_literal: true

class AddEInvoincingToBillingEntities < ActiveRecord::Migration[8.0]
  def change
    add_column :billing_entities, :einvoicing, :boolean, default: false, null: false
  end
end
