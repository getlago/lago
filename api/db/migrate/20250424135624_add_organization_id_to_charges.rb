# frozen_string_literal: true

class AddOrganizationIdToCharges < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :charges, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
