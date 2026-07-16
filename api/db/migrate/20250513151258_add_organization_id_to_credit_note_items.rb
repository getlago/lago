# frozen_string_literal: true

class AddOrganizationIdToCreditNoteItems < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :credit_note_items, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
