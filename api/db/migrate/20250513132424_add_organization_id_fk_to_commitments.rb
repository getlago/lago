# frozen_string_literal: true

class AddOrganizationIdFkToCommitments < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :commitments, :organizations, validate: false
  end
end
