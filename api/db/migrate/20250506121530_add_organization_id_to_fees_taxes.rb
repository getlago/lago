# frozen_string_literal: true

class AddOrganizationIdToFeesTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :fees_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
