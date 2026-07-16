# frozen_string_literal: true

class AddOrganizationIdFkToCommitmentsTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :commitments_taxes, :organizations, validate: false
  end
end
