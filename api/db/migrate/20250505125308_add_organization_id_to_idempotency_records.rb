# frozen_string_literal: true

class AddOrganizationIdToIdempotencyRecords < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :idempotency_records, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
