# frozen_string_literal: true

class ValidateIdempotencyRecordsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :idempotency_records, :organizations
  end
end
