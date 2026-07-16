# frozen_string_literal: true

class AddOrganizationIdToCustomerMetadata < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :customer_metadata, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
