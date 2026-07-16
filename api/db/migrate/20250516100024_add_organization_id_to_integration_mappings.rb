# frozen_string_literal: true

class AddOrganizationIdToIntegrationMappings < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :integration_mappings, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
