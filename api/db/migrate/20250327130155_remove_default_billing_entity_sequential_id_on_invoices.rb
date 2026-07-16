# frozen_string_literal: true

class RemoveDefaultBillingEntitySequentialIdOnInvoices < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    change_column_default :invoices, :billing_entity_sequential_id, from: 0, to: nil

    Invoice.in_batches(of: 1000) do |batch|
      batch.update_all( # rubocop:disable Rails/SkipsModelValidations
        "billing_entity_sequential_id = CASE WHEN organization_sequential_id = 0 THEN NULL ELSE organization_sequential_id END"
      )
    end
  end
end
