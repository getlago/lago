# frozen_string_literal: true

class NotNullOrganizationIdOnCreditNoteItems < ActiveRecord::Migration[8.0]
  def up
    validate_check_constraint :credit_note_items, name: "credit_note_items_organization_id_null"
    change_column_null :credit_note_items, :organization_id, false
    remove_check_constraint :credit_note_items, name: "credit_note_items_organization_id_null"
  end

  def down
    add_check_constraint :credit_note_items, "organization_id IS NOT NULL", name: "credit_note_items_organization_id_null", validate: false
    change_column_null :credit_note_items, :organization_id, true
  end
end
