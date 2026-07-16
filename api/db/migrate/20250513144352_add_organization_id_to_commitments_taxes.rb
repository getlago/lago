# frozen_string_literal: true

class AddOrganizationIdToCommitmentsTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :commitments_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
