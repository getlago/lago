# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invites::Create do
  include_context "with mocked security logger"

  let(:required_permission) { "organization:members:create" }
  let(:membership) { create(:membership) }
  let(:revoked_membership) do
    create(
      :membership,
      organization: membership.organization,
      status: :revoked
    )
  end
  let(:organization) { membership.organization }
  let(:email) { Faker::Internet.email }
  let(:roles) { %w[finance] }

  let(:mutation) do
    <<~GQL
      mutation($input: CreateInviteInput!) {
        createInvite(input: $input) {
          id
          token
          email
          roles
        }
      }
    GQL
  end

  before { create(:role, :finance) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:members:create"

  context "when creating an invite for a new user" do
    subject(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email:,
            roles:
          }
        }
      )
    end

    it "creates an invite" do
      data = result["data"]["createInvite"]

      expect(data["email"]).to eq(email)
      expect(data["roles"]).to eq(roles)
      expect(data["token"]).to be_present
    end

    it_behaves_like "produces a security log", "user.invited" do
      before { result }
    end
  end

  context "when creating an invite with admin role" do
    it "creates an invite with admin role when acting user is admin" do
      admin_role = create(:role, :admin)
      create(:membership_role, membership:, role: admin_role)

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email:,
            roles: ["admin"]
          }
        }
      )

      data = result["data"]["createInvite"]

      expect(data["email"]).to eq(email)
      expect(data["roles"]).to eq(["admin"])
    end

    it "prevents non-admin from creating an invite with admin role" do
      create(:role, :admin)

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email:,
            roles: ["admin"]
          }
        }
      )

      expect_forbidden_error(result)
      error = result["errors"].first
      expect(error["extensions"]["code"]).to eq("cannot_grant_admin")
    end
  end

  context "when creating an invite with custom role" do
    it "creates an invite" do
      create(:role, code: "developer", name: "Developer", organization:, permissions: %w[organization:view])

      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email:,
            roles: ["developer"]
          }
        }
      )

      data = result["data"]["createInvite"]

      expect(data["email"]).to eq(email)
      expect(data["roles"]).to eq(["developer"])
    end
  end

  context "when creating an invite for a revoked user" do
    it "creates an invite" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email: revoked_membership.user.email,
            roles:
          }
        }
      )

      data = result["data"]["createInvite"]

      expect(data["email"]).to eq(revoked_membership.user.email)
      expect(data["token"]).to be_present
    end
  end

  context "when invite already exists" do
    it "returns an error" do
      create(:invite, email:, recipient: membership, organization: membership.organization)

      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email:,
            roles:
          }
        }
      )

      expect(result["errors"].first["extensions"]["status"]).to eq(422)
      expect(result["errors"].first["extensions"]["code"]).to eq("unprocessable_entity")
      expect(result["errors"].first["extensions"]["details"]["invite"]).to eq(["invite_already_exists"])
    end
  end

  context "when email already attached to a user of the organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            email: membership.user.email,
            roles:
          }
        }
      )

      expect(result["errors"].first["extensions"]["status"]).to eq(422)
      expect(result["errors"].first["extensions"]["code"]).to eq("unprocessable_entity")
      expect(result["errors"].first["extensions"]["details"]["email"]).to eq(["email_already_used"])
    end
  end
end
