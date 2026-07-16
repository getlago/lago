# frozen_string_literal: true

class AddOrganizationIdToAdjustedFees < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_reference :adjusted_fees, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
