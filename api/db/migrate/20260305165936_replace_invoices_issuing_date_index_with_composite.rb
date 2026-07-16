# frozen_string_literal: true

class ReplaceInvoicesIssuingDateIndexWithComposite < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    safety_assured do
      # All issuing_date queries are scoped to organization_id;
      # the ordering matches the default sort in the InvoicesQuery
      add_index :invoices, [:organization_id, :issuing_date, :created_at, :id],
        name: :index_invoices_by_cursor,
        order: {issuing_date: :desc, created_at: :desc, id: :asc},
        algorithm: :concurrently,
        if_not_exists: true
    end

    remove_index :invoices, name: :index_invoices_on_issuing_date, algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :invoices, :issuing_date, algorithm: :concurrently, if_not_exists: true

    remove_index name: :index_invoices_by_cursor, algorithm: :concurrently, if_exists: true
  end
end
