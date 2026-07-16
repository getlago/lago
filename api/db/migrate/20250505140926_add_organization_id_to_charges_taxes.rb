# frozen_string_literal: true

class AddOrganizationIdToChargesTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :charges_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
