# frozen_string_literal: true

class ValidateCreditNotesOrganizationsForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :credit_notes, :organizations
  end
end
