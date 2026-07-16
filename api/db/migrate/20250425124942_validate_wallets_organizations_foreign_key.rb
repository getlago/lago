# frozen_string_literal: true

class ValidateWalletsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :wallets, :organizations
  end
end
