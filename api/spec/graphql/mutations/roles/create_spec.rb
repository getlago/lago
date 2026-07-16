# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Roles::Create do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {input: {code:, name:, description:, permissions: role_permissions}}
    )
  end

  include_context "with mocked security logger"

  let(:query) do
    <<-GQL
      mutation($input: CreateRoleInput!) {
        createRole(input: $input) {
          id
          name
          description
          permissions
        }
      }
    GQL
  end

  let(:required_permission) { "roles:create" }
  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:code) { "custom_role" }
  let(:name) { "Custom Role" }
  let(:description) { "A custom role" }
  let(:role_permissions) { %w[customers_view customers_create] }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "roles:create"

  context "with premium organization and custom_roles integration", :premium do
    before { organization.update!(premium_integrations: ["custom_roles"]) }

    it "creates a new role" do
      expect { result }.to change(Role, :count).by(1)
    end

    it "returns created role" do
      role_response = result["data"]["createRole"]

      expect(role_response).to include(
        "name" => name,
        "description" => description,
        "permissions" => role_permissions
      )
    end

    it_behaves_like "produces a security log", "role.created" do
      before { result }
    end

    context "when permissions are sent with underscores" do
      let(:role_permissions) { %w[customers_view customers_create] }

      it "stores permissions with colons and returns them with underscores" do
        role_response = result["data"]["createRole"]

        expect(role_response["permissions"]).to match_array(%w[customers_view customers_create])

        created_role = Role.find(role_response["id"])
        expect(created_role.permissions).to match_array(%w[customers:view customers:create])
      end
    end
  end

  context "with premium organization but without custom_roles integration", :premium do
    before { organization.update!(premium_integrations: []) }

    it "returns an error" do
      expect_graphql_error(result:, message: "premium_integration_missing")
    end
  end

  context "without premium license" do
    it "returns an error" do
      expect_graphql_error(result:, message: "feature_unavailable")
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
        variables: {input: {code:, name:, description:, permissions: role_permissions}}
      )
    end

    let!(:membership) { create(:membership, organization:, roles: [:admin]) }

    context "with premium organization and custom_roles integration", :premium do
      before { organization.update!(premium_integrations: ["custom_roles"]) }

      it "allows admin to create a role" do
        expect { result }.to change(Role, :count).by(1)
      end
    end

    context "without premium license" do
      it "returns feature_unavailable error" do
        expect_graphql_error(result:, message: "feature_unavailable")
      end
    end
  end
end
