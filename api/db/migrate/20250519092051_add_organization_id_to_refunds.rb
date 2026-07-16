# frozen_string_literal: true

class AddOrganizationIdToRefunds < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :refunds, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
