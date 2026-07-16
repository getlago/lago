# frozen_string_literal: true

class ValidatePlansTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :plans_taxes, :organizations
  end
end
