# frozen_string_literal: true

class ValidateDataExportPartsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :data_export_parts, :organizations
  end
end
