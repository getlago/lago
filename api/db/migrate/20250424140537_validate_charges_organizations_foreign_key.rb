# frozen_string_literal: true

class ValidateChargesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :charges, :organizations
  end
end
