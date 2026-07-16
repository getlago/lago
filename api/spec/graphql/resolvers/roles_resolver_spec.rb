# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::RolesResolver do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )
  end

  let(:query) do
    <<~GQL
      query {
        roles {
          id name description admin permissions
          memberships {
            id
            user { id email }
          }
        }
      }
    GQL
  end

  let(:required_permission) { "roles:view" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:other_user) { create(:user, email: "other@example.com") }
  let!(:other_membership) { create(:membership, organization:, user: other_user) }

  before do
    create(:role, :admin)
    create(:role, :finance)
    operator_role = create(:role, organization:, name: "OPERATOR")
    create(:role, organization:, name: "accountant")
    create(:membership_role, membership: other_membership, role: operator_role, organization:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "roles:view"

  it "returns roles sorted by organization_id nulls first then by lower(name)" do
    roles_response = result["data"]["roles"]

    expect(roles_response.map { |r| r["name"] }).to eq(%w[Admin Finance accountant OPERATOR])
  end

  it "returns role attributes" do
    roles_response = result["data"]["roles"]
    admin_role = roles_response.find { |r| r["name"] == "Admin" }

    all_permissions = Permission.permissions_hash.each_key.map { |p| p.tr(":", "_") }

    expect(admin_role["name"]).to eq("Admin")
    expect(admin_role["admin"]).to be(true)
    expect(admin_role["permissions"]).to match_array(all_permissions)
  end

  it "does not return roles from other organizations" do
    other_organization = create(:organization)
    create(:role, organization: other_organization, name: "OtherOrgRole")

    roles_response = result["data"]["roles"]

    expect(roles_response.map { |r| r["name"] }).not_to include("OtherOrgRole")
  end

  it "returns memberships with user for a role" do
    roles_response = result["data"]["roles"]
    operator_role = roles_response.find { |r| r["name"] == "OPERATOR" }

    expect(operator_role["memberships"].size).to eq(1)
    expect(operator_role["memberships"].first["user"]["email"]).to eq("other@example.com")
  end

  it "does not return memberships from other organizations" do
    admin_role = Role.find_by(admin: true)
    other_org = create(:organization)
    other_org_membership = create(:membership, organization: other_org)
    create(:membership_role, membership: other_org_membership, role: admin_role, organization: other_org)

    roles_response = result["data"]["roles"]
    admin = roles_response.find { |r| r["name"] == "Admin" }

    expect(admin["memberships"]).to be_empty
  end
end
