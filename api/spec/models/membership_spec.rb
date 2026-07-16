# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership do
  subject(:membership) { create(:membership) }

  it { is_expected.to have_many(:data_exports) }
  it { is_expected.to have_many(:membership_roles) }
  it { is_expected.to have_many(:roles).through(:membership_roles) }

  it_behaves_like "paper_trail traceable"

  describe ".admins" do
    let(:organization) { create(:organization) }
    let(:admin_membership) { create(:membership, organization:) }
    let(:finance_membership) { create(:membership, organization:) }

    before do
      create(:membership_role, membership: admin_membership, role: create(:role, :admin))
      create(:membership_role, membership: finance_membership, role: create(:role, :finance))
    end

    it "returns only memberships with admin roles" do
      expect(described_class.admins).to eq([admin_membership])
    end
  end

  describe "#admin?" do
    it "returns true when membership has admin role" do
      create(:membership_role, membership:, role: create(:role, :admin))
      expect(membership.admin?).to be true
    end

    it "returns false when membership has no admin role" do
      create(:membership_role, membership:, role: create(:role, :finance))
      expect(membership.admin?).to be false
    end

    it "returns false when membership has no roles" do
      expect(membership.admin?).to be false
    end
  end

  describe "#mark_as_revoked" do
    it "revokes the membership with a Time" do
      freeze_time do
        expect { membership.mark_as_revoked! }
          .to change { membership.reload.status }.from("active").to("revoked")
          .and change(membership, :revoked_at).from(nil).to(Time.current)
      end
    end
  end

  describe "#permissions_hash" do
    subject(:permissions_hash) { membership.permissions_hash }

    context "with admin role" do
      let(:membership) { create(:membership, roles: %i[admin]) }

      it "includes all existing permissions" do
        expect(permissions_hash.keys).to match_array(Permission.permissions_hash.keys)
      end

      it "returns all permissions as true" do
        expect(permissions_hash.values).to all(be true)
      end
    end

    context "with finance role" do
      let(:membership) { create(:membership, roles: %i[finance]) }

      it "includes all existing permissions" do
        expect(permissions_hash.keys).to match_array(Permission.permissions_hash.keys)
      end

      it "returns true for finance-specific permissions" do
        expect(permissions_hash).to include("analytics:view" => true)
      end

      it "returns false for non-finance permissions" do
        expect(permissions_hash).to include("coupons:attach" => false)
      end
    end

    context "with manager role" do
      let(:membership) { create(:membership, roles: %i[manager]) }

      it "includes all existing permissions" do
        expect(permissions_hash.keys).to match_array(Permission.permissions_hash.keys)
      end

      it "returns true for manager-specific permissions" do
        expect(permissions_hash).to include("coupons:attach" => true)
      end

      it "returns false for non-manager permissions" do
        expect(permissions_hash).to include("pricing_units:view" => false)
      end
    end

    context "with custom role" do
      let(:organization) { create(:organization) }
      let(:role) { create(:role, :custom, organization:, permissions: %w[foo addons:view]) }
      let(:membership) { create(:membership, organization:, role:) }

      it "includes all existing permissions" do
        expect(permissions_hash.keys).to match_array(Permission.permissions_hash.keys)
      end

      it "excludes non-existing permissions" do
        expect(permissions_hash).not_to be_key("foo")
      end

      it "returns true for custom permissions" do
        expect(permissions_hash).to include("addons:view" => true)
      end

      it "returns false for other permissions" do
        expect(permissions_hash.except("addons:view").values).to all(be false)
      end
    end

    context "with mixed roles" do
      let(:organization) { create(:organization) }
      let(:role) { create(:role, :custom, organization:, permissions: %w[foo addons:view]) }
      let(:membership) { create(:membership, organization:, role:, roles: %i[finance]) }

      it "includes all existing permissions" do
        expect(permissions_hash.keys).to match_array(Permission.permissions_hash.keys)
      end

      it "excludes non-existing permissions" do
        expect(permissions_hash).not_to be_key("foo")
      end

      it "returns true for custom permissions" do
        expect(permissions_hash).to include("addons:view" => true)
      end

      it "returns true for predefined permissions" do
        expect(permissions_hash).to include("analytics:view" => true)
      end

      it "returns false for disabled permissions" do
        expect(permissions_hash).to include("coupons:attach" => false)
      end
    end
  end
end
