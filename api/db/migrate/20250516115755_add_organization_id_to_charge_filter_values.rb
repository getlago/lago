# frozen_string_literal: true

class AddOrganizationIdToChargeFilterValues < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :charge_filter_values, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
