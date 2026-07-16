# frozen_string_literal: true

class ValidateFeesTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :fees_taxes, :organizations
  end
end
