# frozen_string_literal: true

class AddOrganizationIdToChargeFilters < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :charge_filters, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
