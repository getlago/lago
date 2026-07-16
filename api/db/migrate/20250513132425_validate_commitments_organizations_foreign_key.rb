# frozen_string_literal: true

class ValidateCommitmentsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :commitments, :organizations
  end
end
