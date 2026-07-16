# frozen_string_literal: true

class AddOrganizationIdToCommitments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :commitments, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
