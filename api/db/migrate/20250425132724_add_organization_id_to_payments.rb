# frozen_string_literal: true

class AddOrganizationIdToPayments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :payments, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
