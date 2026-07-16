# frozen_string_literal: true

class ValidateCreditNoteItemsOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :credit_note_items, :organizations
  end
end
