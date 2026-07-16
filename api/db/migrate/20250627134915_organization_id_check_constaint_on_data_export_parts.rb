# frozen_string_literal: true

class OrganizationIdCheckConstaintOnDataExportParts < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :data_export_parts,
      "organization_id IS NOT NULL",
      name: "data_export_parts_organization_id_null",
      validate: false
  end
end
