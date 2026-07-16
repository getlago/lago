# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Roles::Destroy do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {input: {id: role.id}}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: DestroyRoleInput!) {
        destroyRole(input: $input) {
          id
        }
      }
    GQL
  end
  let(:required_permission) { "roles:delete" }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:role) { create(:role, organization:) }

  include_context "with mocked security logger"

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "roles:delete"

  context "when role exists in the current organization" do
    it "soft-deletes the role" do
      expect { result }.to change { role.reload.deleted_at }.from(nil)
    end

    it "returns deleted role" do
      role_response = result["data"]["destroyRole"]

      expect(role_response["id"]).to eq(role.id)
    end

    it_behaves_like "produces a security log", "role.deleted" do
      before { result }
    end
  end

  context "when role does not exist in the current organization" do
    let(:role) { create(:role) }

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "when role is predefined" do
    let(:role) { create(:role, :predefined, name: "Finance") }

    it "returns an error" do
      expect_graphql_error(result:, message: "predefined_role")
    end
  end

  context "when role has assigned members" do
    before { create(:membership_role, membership:, role:) }

    it "does not delete the role" do
      expect { result }.not_to change { role.reload.deleted_at }
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "role_assigned_to_members")
    end
  end

  describe "with admin role permissions" do
    subject(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        current_membership: membership,
        permissions: membership.permissions_hash,
        query:,
        variables: {input: {id: role.id}}
      )
    end

    let(:membership) { create(:membership, organization:, roles: [:admin]) }

    it "allows admin to delete a role" do
      expect { result }.to change { role.reload.deleted_at }.from(nil)
    end
  end
end
