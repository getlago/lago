# frozen_string_literal: true

class ValidateCommitmentsTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :commitments_taxes, :organizations
  end
end
