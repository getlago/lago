# frozen_string_literal: true

class ValidatesAddOnsTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :add_ons_taxes, :organizations
  end
end
