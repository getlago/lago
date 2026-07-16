# frozen_string_literal: true

class AddOrganizationIdFkToCreditNotesTaxes < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :credit_notes_taxes, :organizations, validate: false
  end
end
