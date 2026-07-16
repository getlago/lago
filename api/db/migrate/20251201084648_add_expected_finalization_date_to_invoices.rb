# frozen_string_literal: true

class AddExpectedFinalizationDateToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :expected_finalization_date, :date
  end
end
