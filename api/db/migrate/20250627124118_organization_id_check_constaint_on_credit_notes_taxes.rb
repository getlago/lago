# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCreditNotesTaxes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :credit_notes_taxes,
      "organization_id IS NOT NULL",
      name: "credit_notes_taxes_organization_id_null",
      validate: false
  end
end
