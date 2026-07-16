# frozen_string_literal: true

class AddOrganizationIdFkToCreditNotes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :credit_notes, :organizations, validate: false
  end
end
