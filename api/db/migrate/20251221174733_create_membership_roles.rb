# frozen_string_literal: true

class CreateMembershipRoles < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    unless index_exists?(:memberships, [:id, :organization_id], name: "index_memberships_by_id_and_organization")
      add_index :memberships, [:id, :organization_id], unique: true, name: "index_memberships_by_id_and_organization", algorithm: :concurrently
    end

    unless table_exists?(:membership_roles)
      create_table :membership_roles, id: :uuid do |t|
        t.uuid :organization_id, null: false
        t.uuid :membership_id, null: false
        t.references :role, index: true, foreign_key: true, type: :uuid, null: false
        t.datetime :deleted_at
        t.timestamps

        t.index [:membership_id, :role_id],
          unique: true,
          where: "deleted_at IS NULL",
          name: "index_membership_roles_uniqueness"
        t.index [:membership_id, :organization_id],
          where: "deleted_at IS NULL",
          name: "index_membership_roles_by_membership_and_organization"

        t.foreign_key :memberships,
          column: [:membership_id, :organization_id],
          primary_key: [:id, :organization_id],
          name: "membership_role_membership_fk"
      end
    end
  end

  def down
    drop_table :membership_roles

    if index_exists?(:memberships, [:id, :organization_id], name: "index_memberships_by_id_and_organization")
      remove_index :memberships, name: "index_memberships_by_id_and_organization"
    end
  end
end
