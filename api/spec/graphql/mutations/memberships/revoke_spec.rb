# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Memberships::Revoke do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:members:update" }
  let(:admin_role) { create(:role, :admin) }
  let(:finance_role) { create(:role, :finance) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:mutation) do
    <<-GQL
      mutation($input: RevokeMembershipInput!) {
        revokeMembership(input: $input) {
          id
          revokedAt
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:members:update"

  context "when revoking another membership" do
    subject(:result) do
      execute_graphql(
        current_organization: organization,
        current_user: membership.user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: membership_to_remove.id}
        }
      )
    end

    let(:membership_to_remove) { create(:membership, organization:) }

    before do
      create(:membership_role, membership: membership_to_remove, role: admin_role)
      create(:membership_role, membership:, role: admin_role)
    end

    it "revokes a membership" do
      data = result["data"]["revokeMembership"]

      expect(data["id"]).to eq(membership_to_remove.id)
      expect(data["revokedAt"]).to be_present
    end

    it_behaves_like "produces a security log", "user.deleted" do
      before { result }
    end
  end

  it "Cannot Revoke my own membership" do
    result = execute_graphql(
      current_organization: organization,
      current_user: membership.user,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: membership.id}
      }
    )

    expect(result["errors"].first["message"]).to eq("Method Not Allowed")
    expect(result["errors"].first["extensions"]["code"]).to eq("cannot_revoke_own_membership")
    expect(result["errors"].first["extensions"]["status"]).to eq(405)
  end

  it "cannot revoke membership if it's the last admin of the organization" do
    # `finance` users normally don't have delete permissions on memberships
    # but here the permissions array is passed regardless of the actual user permission
    create(:membership_role, membership:, role: admin_role)
    other_user = create(:membership, organization:)
    create(:membership_role, membership: other_user, role: finance_role)

    result = execute_graphql(
      current_organization: organization,
      current_user: other_user.user,
      current_membership: other_user,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {id: membership.id}
      }
    )

    expect(result["errors"].first["message"]).to eq("Method Not Allowed")
    expect(result["errors"].first["extensions"]["code"]).to eq("last_admin")
    expect(result["errors"].first["extensions"]["status"]).to eq(405)
  end
end
