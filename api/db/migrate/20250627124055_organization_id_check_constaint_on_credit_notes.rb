# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCreditNotes < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :credit_notes,
      "organization_id IS NOT NULL",
      name: "credit_notes_organization_id_null",
      validate: false
  end
end
