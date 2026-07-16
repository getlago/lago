# frozen_string_literal: true

class ValidateChargeFiltersOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :charge_filters, :organizations
  end
end
