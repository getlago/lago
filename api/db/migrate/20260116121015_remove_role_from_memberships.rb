# frozen_string_literal: true

class RemoveRoleFromMemberships < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      remove_column :memberships, :role, :integer
    end
  end
end
