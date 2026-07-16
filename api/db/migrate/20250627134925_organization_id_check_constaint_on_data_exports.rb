# frozen_string_literal: true

class OrganizationIdCheckConstaintOnDataExports < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :data_exports,
      "organization_id IS NOT NULL",
      name: "data_exports_organization_id_null",
      validate: false
  end
end
