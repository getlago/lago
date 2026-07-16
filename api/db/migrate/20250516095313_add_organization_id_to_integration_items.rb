# frozen_string_literal: true

class AddOrganizationIdToIntegrationItems < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :integration_items, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
