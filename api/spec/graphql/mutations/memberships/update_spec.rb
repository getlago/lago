# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Memberships::Update do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:members:update" }
  let(:admin_role) { create(:role, :admin) }
  let(:finance_role) { create(:role, :finance) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:user) { membership.user }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateMembershipInput!) {
        updateMembership(input: $input) {
          id
          roles
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:members:update"

  describe "Membership update mutation" do
    subject(:result) do
      execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: membership_to_edit.id,
            roles: %w[admin]
          }
        }
      )
    end

    let(:membership_to_edit) { create(:membership, organization:) }

    before do
      create(:membership_role, membership: membership_to_edit, role: finance_role)
      create(:membership_role, membership:, role: admin_role)
    end

    it "returns the updated membership" do
      data = result["data"]["updateMembership"]

      expect(data["id"]).to eq(membership_to_edit.id)
      expect(data["roles"]).to eq(%w[Admin])
    end

    it_behaves_like "produces a security log", "user.role_edited" do
      before { result }
    end
  end

  describe "self-promotion with custom role" do
    subject(:result) do
      execute_graphql(
        current_organization: organization,
        current_user: user,
        current_membership: membership,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: membership.id,
            roles: %w[admin]
          }
        }
      )
    end

    let(:custom_role) do
      create(:role, :custom,
        organization: organization,
        code: "accounting",
        name: "Accounting",
        permissions: %w[organization:members:update organization:view])
    end

    before do
      admin_role
      create(:membership_role, membership:, role: custom_role)
    end

    it "prevents a non-admin member from promoting themselves to admin" do
      expect_forbidden_error(result)
      error = result["errors"].first
      expect(error["extensions"]["code"]).to eq("cannot_grant_admin")
    end
  end

  describe "non-admin promoting another member to admin" do
    subject(:result) do
      execute_graphql(
        current_organization: organization,
        current_user: user,
        current_membership: membership,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: other_membership.id,
            roles: %w[admin]
          }
        }
      )
    end

    let(:other_membership) { create(:membership, organization:) }

    let(:custom_role) do
      create(:role, :custom,
        organization: organization,
        code: "accounting",
        name: "Accounting",
        permissions: %w[organization:members:update organization:view])
    end

    before do
      admin_role
      create(:membership_role, membership:, role: custom_role)
      create(:membership_role, membership: other_membership, role: finance_role)
    end

    it "prevents a non-admin from promoting another member to admin" do
      expect_forbidden_error(result)
      error = result["errors"].first
      expect(error["extensions"]["code"]).to eq("cannot_grant_admin")
    end
  end
end
