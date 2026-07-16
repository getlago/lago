# frozen_string_literal: true

class AddPolymorphicRefundableToRefunds < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :refunds, :refundable, type: :uuid, polymorphic: true, index: {algorithm: :concurrently}

    add_column :refunds, :reason, :string

    # Last in forward = first in reverse. If any row has credit_note_id
    # NULL (M4 activation refunds), rollback aborts here before any other
    # column is dropped, leaving the schema intact.
    safety_assured do
      change_column_null :refunds, :credit_note_id, true
    end
  end
end
