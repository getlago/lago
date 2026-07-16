# frozen_string_literal: true

class PopulateMembershipRolesFromMemberships < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO membership_roles (id, organization_id, membership_id, role_id, created_at, updated_at)
        SELECT
          gen_random_uuid(),
          m.organization_id,
          m.id,
          CASE m.role
            WHEN 0 THEN (SELECT id FROM roles WHERE admin)
            WHEN 1 THEN (SELECT id FROM roles WHERE name = 'Manager' AND organization_id IS NULL)
            WHEN 2 THEN (SELECT id FROM roles WHERE name = 'Finance' AND organization_id IS NULL)
          END,
          NOW(),
          NOW()
        FROM memberships m
        LEFT JOIN membership_roles mr ON mr.membership_id = m.id AND mr.deleted_at IS NULL
        WHERE mr.id IS NULL
        ON CONFLICT DO NOTHING;
      SQL
    end
  end

  def down
  end
end
