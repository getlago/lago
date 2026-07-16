# frozen_string_literal: true

class ValidateAdjustedFeesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :adjusted_fees, :organizations
  end
end
