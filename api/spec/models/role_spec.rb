# frozen_string_literal: true

require "rails_helper"

RSpec.describe Role do
  subject(:role) { build(:role) }

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it { is_expected.to belong_to(:organization).optional }
    it { is_expected.to have_many(:membership_roles) }
    it { is_expected.to have_many(:memberships).through(:membership_roles) }
  end

  describe "callbacks" do
    it "normalizes name before validation" do
      role = build(:role, name: "  Some   Role  ")
      role.valid?
      expect(role.name).to eq("Some Role")
    end
  end

  describe "scopes" do
    describe ".with_code" do
      let(:organization) { create(:organization) }
      let!(:developer) { create(:role, code: :developer, organization:) }

      before { create(:role, code: :designer, organization:) }

      it "finds role by exact code" do
        expect(described_class.with_code("developer")).to contain_exactly(developer)
      end

      it "returns empty when code does not match" do
        expect(described_class.with_code("nonexistent")).to be_empty
      end
    end

    describe ".with_organization" do
      let(:organization) { create(:organization) }
      let(:other_organization) { create(:organization) }
      let!(:system_role) { create(:role, :admin) }
      let!(:org_role) { create(:role, organization:) }

      before { create(:role, organization: other_organization) }

      it "returns system roles (organization_id is nil) and roles for given organization" do
        result = described_class.with_organization(organization.id)

        expect(result).to contain_exactly(system_role, org_role)
      end

      it "returns only system roles when organization_id is nil" do
        result = described_class.with_organization(nil)

        expect(result).to contain_exactly(system_role)
      end
    end
  end

  describe "validations" do
    context "when role is custom" do
      let(:role) { build(:role, :custom) }

      it { is_expected.to be_valid }

      it "is invalid without code" do
        role.code = nil
        expect(role).not_to be_valid
      end

      it "is invalid with empty code" do
        role.code = ""
        expect(role).not_to be_valid
      end

      it "is invalid with code longer than 100 characters" do
        role.code = "a" * 101
        expect(role).not_to be_valid
      end

      it "is invalid with code containing invalid characters" do
        %w[UPPER Code-with-dash code.with.dot code\ with\ space].each do |code|
          role.code = code
          expect(role).not_to be_valid
          expect(role.errors[:code]).to include("value_is_invalid")
        end
      end

      it "is invalid when code exists in the same organization" do
        create(:role, :custom, code: role.code, organization: role.organization)
        expect(role).not_to be_valid
      end

      it "is valid when code exists in another organization" do
        create(:role, :custom, code: role.code)
        expect(role).to be_valid
      end

      it "is invalid with reserved codes" do
        %w[admin finance manager].each do |code|
          role.code = code
          expect(role).not_to be_valid
        end
      end

      it "is invalid without name" do
        role.name = nil
        expect(role).not_to be_valid
      end

      it "is invalid with empty name" do
        role.name = ""
        expect(role).not_to be_valid
      end

      it "is invalid with name longer than 100 characters" do
        role.name = "a" * 101
        expect(role).not_to be_valid
      end

      it "is invalid with description longer than 255 characters" do
        role.description = "a" * 256
        expect(role).not_to be_valid
      end

      it "is invalid with empty permissions" do
        role.permissions = []
        expect(role).not_to be_valid
      end
    end
  end

  describe "database constraints" do
    let!(:organization) { create(:organization) }

    it "rejects empty name" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'test_code', '', ARRAY['test:view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects admin with permissions" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'super_admin', 'SuperAdmin', true, ARRAY['test:view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects predefined roles with permissions" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'accountant', 'Accountant', ARRAY['test:view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects custom roles without permissions" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'accountant', 'Accountant', '#{organization.id}', '{}'::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects permissions containing empty strings" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'bad_role', 'BadRole', '#{organization.id}', ARRAY['test:view', '']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects permission starting with colon" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'bad_role', 'BadRole', '#{organization.id}', ARRAY[':view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects permission ending with colon" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'bad_role', 'BadRole', '#{organization.id}', ARRAY['test:']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects permission with double colon" do
      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'bad_role', 'BadRole', '#{organization.id}', ARRAY['test::view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "allows only one active admin role" do
      described_class.connection.execute(<<~SQL)
        INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
        VALUES ('#{SecureRandom.uuid}', 'first_admin', 'FirstAdmin', true, ARRAY[]::text[], now(), now())
      SQL

      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'second_admin', 'SecondAdmin', true, ARRAY[]::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects duplicate codes within same organization" do
      role = create(:role, code: "developer")

      expect {
        described_class.connection.execute(<<~SQL)
          INSERT INTO roles (id, code, name, organization_id, permissions, created_at, updated_at)
          VALUES ('#{SecureRandom.uuid}', 'developer', 'Another Developer', '#{role.organization_id}', ARRAY['test:view']::text[], now(), now())
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "prevents modification of predefined role" do
      admin_id = SecureRandom.uuid
      described_class.connection.execute(<<~SQL)
        INSERT INTO roles (id, code, name, admin, permissions, created_at, updated_at)
        VALUES ('#{admin_id}', 'predefined_admin', 'PredefinedAdmin', true, ARRAY[]::text[], now(), now())
      SQL

      expect {
        described_class.connection.execute(<<~SQL)
          UPDATE roles SET description = 'Modified' WHERE id = '#{admin_id}'
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "prevents moving custom role to another organization" do
      role = create(:role, :custom, organization:)
      other_organization = create(:organization)

      expect {
        described_class.connection.execute(<<~SQL)
          UPDATE roles SET organization_id = '#{other_organization.id}' WHERE id = '#{role.id}'
        SQL
      }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "deduplicates permissions" do
      role = create(:role, :custom, organization:, permissions: %w[b:action a:action])

      described_class.connection.execute(<<~SQL)
        UPDATE roles SET permissions = ARRAY['z:action', 'a:action', 'z:action']::text[] WHERE id = '#{role.id}'
      SQL

      role.reload
      expect(role.permissions).to eq(%w[a:action z:action])
    end
  end
end
