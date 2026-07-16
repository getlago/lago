# frozen_string_literal: true

class AddOrganizationIdFkToIdempotencyRecords < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :idempotency_records, :organizations, validate: false
  end
end
