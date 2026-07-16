# frozen_string_literal: true

class AddFinalizedAtTimestampToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :finalized_at, :timestamp
  end
end
