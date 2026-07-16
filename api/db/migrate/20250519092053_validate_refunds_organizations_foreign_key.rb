# frozen_string_literal: true

class ValidateRefundsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :refunds, :organizations
  end
end
