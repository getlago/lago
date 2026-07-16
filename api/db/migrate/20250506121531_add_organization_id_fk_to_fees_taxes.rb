# frozen_string_literal: true

class AddOrganizationIdFkToFeesTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :fees_taxes, :organizations, validate: false
  end
end
