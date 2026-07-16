# frozen_string_literal: true

class AddOrganizationIdFkToCharges < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :charges, :organizations, validate: false
  end
end
