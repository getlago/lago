# frozen_string_literal: true

class AddOrganizationIdToCreditNotesTaxes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :credit_notes_taxes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
