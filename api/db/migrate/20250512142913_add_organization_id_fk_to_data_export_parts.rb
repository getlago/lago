# frozen_string_literal: true

class AddOrganizationIdFkToDataExportParts < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :data_export_parts, :organizations, validate: false
  end
end
