# frozen_string_literal: true

class ValidateCreditNotesTaxesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :credit_notes_taxes, :organizations
  end
end
