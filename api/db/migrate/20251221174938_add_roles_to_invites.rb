# frozen_string_literal: true

class AddRolesToInvites < ActiveRecord::Migration[8.0]
  # Disable DDL transaction to enable null check constraint addition without locking the table for long.
  disable_ddl_transaction!

  def up
    safety_assured do
      change_table :invites, bulk: true do |t|
        t.string :roles, array: true, default: [], null: false
      end

      # backfill existing data
      execute <<~SQL.squish
        UPDATE invites SET roles = ARRAY[
          CASE role
            WHEN 0 THEN 'admin'
            WHEN 1 THEN 'manager'
            WHEN 2 THEN 'finance'
          END
        ]
      SQL
    end
  end

  def down
    safety_assured { remove_column(:invites, :roles) }
  end
end
