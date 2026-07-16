# frozen_string_literal: true

class AllowNullTaxesForAppliedTaxes < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      [:invoices_taxes, :fees_taxes].each do |table|
        remove_foreign_key table, :taxes
        change_column_null table, :tax_id, true
        add_foreign_key table, :taxes, on_delete: :nullify
      end
    end
  end
end
