# frozen_string_literal: true

class ValidateChargesTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :charges_taxes, :organizations
  end
end
