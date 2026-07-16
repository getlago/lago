# frozen_string_literal: true

class AddOrganizationIdToCredits < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :credits, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
