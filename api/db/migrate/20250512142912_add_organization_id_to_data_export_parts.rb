# frozen_string_literal: true

class AddOrganizationIdToDataExportParts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :data_export_parts, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
