# frozen_string_literal: true

class AddOrganizationIdToSubscriptions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :subscriptions, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
