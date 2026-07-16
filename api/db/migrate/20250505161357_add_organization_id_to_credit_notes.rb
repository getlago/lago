# frozen_string_literal: true

class AddOrganizationIdToCreditNotes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :credit_notes, :organization, type: :uuid, index: {algorithm: :concurrently}
  end
end
