# frozen_string_literal: true

class MakeMembershipsRoleOptional < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      change_column_null :memberships, :role, true
      change_column_default :memberships, :role, from: 0, to: nil
    end
  end

  def down
    safety_assured do
      execute "UPDATE memberships SET role = 0 WHERE role IS NULL;"
      change_column_default :memberships, :role, from: nil, to: 0
      change_column_null :memberships, :role, false
    end
  end
end
