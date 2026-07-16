# frozen_string_literal: true

class MakeInvitesRoleOptional < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      change_column_null :invites, :role, true
      change_column_default :invites, :role, from: 0, to: nil
    end
  end

  def down
    safety_assured do
      execute "UPDATE invites SET role = 0 WHERE role IS NULL;"
      change_column_default :invites, :role, from: nil, to: 0
      change_column_null :invites, :role, false
    end
  end
end
