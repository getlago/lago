# frozen_string_literal: true

class ValidatePaymentsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :payments, :organizations
  end
end
