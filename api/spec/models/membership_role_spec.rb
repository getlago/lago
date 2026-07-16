# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipRole do
  subject(:membership_role) { build(:membership_role) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:membership)
      expect(subject).to belong_to(:role)
    end
  end

  describe "scopes" do
    describe ".admins" do
      it "returns only admin member roles" do
        membership_role = create(:membership_role)
        admin_role_id = SecureRandom.uuid

        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
          VALUES ('#{admin_role_id}', 'test_admin', 'TestAdmin', true, ARRAY[]::text[], now(), now())
        SQL

        admin_membership_role_id = SecureRandom.uuid
        described_class.connection.execute(<<~SQL)
          INSERT INTO membership_roles (id, organization_id, membership_id, role_id, created_at, updated_at)
          VALUES (
            '#{admin_membership_role_id}',
            '#{membership_role.organization_id}',
            '#{membership_role.membership_id}',
            '#{admin_role_id}',
            now(),
            now()
          )
        SQL

        expect(described_class.admins.pluck(:id)).to eq([admin_membership_role_id])
      end
    end
  end

  describe "validations" do
    it "forbids discarding the last admin role in organization" do
      membership = create(:membership)
      admin_role_id = SecureRandom.uuid

      described_class.connection.execute(<<~SQL)
        INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
        VALUES ('#{admin_role_id}', 'test_admin_#{admin_role_id[0..7]}', 'TestAdmin', true, ARRAY[]::text[], now(), now())
      SQL

      membership_role_id = SecureRandom.uuid
      described_class.connection.execute(<<~SQL)
        INSERT INTO membership_roles (id, organization_id, membership_id, role_id, created_at, updated_at)
        VALUES (
          '#{membership_role_id}',
          '#{membership.organization_id}',
          '#{membership.id}',
          '#{admin_role_id}',
          now(),
          now()
        )
      SQL

      membership_role = described_class.find(membership_role_id)

      expect(membership_role.discard).to be(false)
    end

    it "allows discarding admin role when another admin exists" do
      membership = create(:membership)
      organization = membership.organization
      other_membership = create(:membership, organization:)
      custom_role = create(:role, organization:)

      membership_role = create(:membership_role, :admin, membership:)
      create(:membership_role, membership:, role: custom_role)
      create(:membership_role, :admin, membership: other_membership)

      expect(membership_role.discard).to be(true)
    end

    it "forbids discarding last admin role when other admins have revoked membership" do
      membership = create(:membership)
      organization = membership.organization
      revoked_membership = create(:membership, :revoked, organization:)
      custom_role = create(:role, organization:)

      membership_role = create(:membership_role, :admin, membership:)
      create(:membership_role, membership:, role: custom_role)
      create(:membership_role, :admin, membership: revoked_membership)

      expect(membership_role.discard).to be(false)
    end

    it "forbids discarding the last role of membership" do
      membership_role = create(:membership_role)

      expect(membership_role.discard).to be(false)
    end

    it "allows discarding role when membership has another role" do
      membership_role = create(:membership_role)
      other_role = create(:role, organization: membership_role.organization)
      create(:membership_role, membership: membership_role.membership, role: other_role)

      expect(membership_role.discard).to be(true)
    end

    it "rejects role from different organization" do
      membership_role = build(:membership_role, role: create(:role))

      expect(membership_role).not_to be_valid
      expect(membership_role.errors[:role]).to include("invalid_value")
    end

    it "allows predefined role (without organization)" do
      membership_role = build(:membership_role, role: create(:role, :admin))

      expect(membership_role).to be_valid
    end

    it "forbids any modification except discard" do
      membership_role = create(:membership_role)
      membership_role.role = create(:role, organization: membership_role.organization)

      expect(membership_role).not_to be_valid
      expect(membership_role.errors[:base]).to include("modification_not_allowed")
    end
  end
end
