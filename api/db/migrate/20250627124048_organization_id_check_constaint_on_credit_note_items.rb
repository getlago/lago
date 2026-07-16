# frozen_string_literal: true

class OrganizationIdCheckConstaintOnCreditNoteItems < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :credit_note_items,
      "organization_id IS NOT NULL",
      name: "credit_note_items_organization_id_null",
      validate: false
  end
end
