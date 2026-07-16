# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sources::MembershipsForRole do
  subject(:source) { described_class.new(organization) }

  let(:membership_role) { create(:membership_role) }
  let(:organization) { membership_role.organization }
  let(:membership) { membership_role.membership }
  let(:role) { membership_role.role }

  describe "#fetch" do
    it "returns memberships for a role" do
      result = source.fetch([role.id])

      expect(result[0]).to contain_exactly(membership)
    end

    it "returns empty array for roles without memberships" do
      empty_role = create(:role, organization:)

      result = source.fetch([empty_role.id])

      expect(result[0]).to be_blank
    end

    it "does not return memberships from other organizations" do
      role = create(:role, :admin)
      create(:membership_role, membership:, role:, organization:)
      other_membership = create(:membership_role, role:).membership

      result = source.fetch([role.id])

      expect(result[0]).to contain_exactly(membership)
      expect(result[0]).not_to include(other_membership)
    end

    it "does not return revoked memberships" do
      revoked_membership = create(:membership, :revoked, organization:)
      create(:membership_role, membership: revoked_membership, role:, organization:)

      result = source.fetch([role.id])

      expect(result[0]).to contain_exactly(membership)
    end
  end
end
