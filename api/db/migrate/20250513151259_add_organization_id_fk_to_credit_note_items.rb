# frozen_string_literal: true

class AddOrganizationIdFkToCreditNoteItems < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :credit_note_items, :organizations, validate: false
  end
end
