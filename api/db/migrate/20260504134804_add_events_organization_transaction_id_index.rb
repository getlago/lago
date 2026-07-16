# frozen_string_literal: true

class AddEventsOrganizationTransactionIdIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :events,
      [:organization_id, :transaction_id],
      where: "deleted_at IS NULL",
      name: "index_events_on_organization_id_and_transaction_id",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
