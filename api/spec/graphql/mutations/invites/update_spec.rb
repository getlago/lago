# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invites::Update do
  let(:required_permission) { "organization:members:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:user) { membership.user }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateInviteInput!) {
        updateInvite(input: $input) {
          id
          roles
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:members:update"

  describe "Invite update mutation" do
    context "with an existing invite" do
      let(:invite) { create(:invite, organization:, roles: %w[admin]) }

      before { create(:role, :finance) }

      it "returns the updated invite" do
        result = execute_graphql(
          current_organization: organization,
          current_user: user,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              id: invite.id,
              roles: %w[finance]
            }
          }
        )

        data = result["data"]["updateInvite"]

        expect(data["id"]).to eq(invite.id)
        expect(data["roles"]).to eq(%w[finance])
      end
    end

    context "when non-admin sets admin role on invite" do
      let(:invite) { create(:invite, organization:, roles: %w[finance]) }

      before { create(:role, :admin) }

      it "returns an error" do
        result = execute_graphql(
          current_organization: organization,
          current_user: user,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {
              id: invite.id,
              roles: %w[admin]
            }
          }
        )

        expect_forbidden_error(result)
        error = result["errors"].first
        expect(error["extensions"]["code"]).to eq("cannot_grant_admin")
      end
    end

    context "when the invite accepted" do
      let(:invite) { create(:invite, organization:, status: :accepted) }

      it "returns an error" do
        result = execute_graphql(
          current_organization: organization,
          permissions: required_permission,
          current_user: user,
          query: mutation,
          variables: {
            input: {id: invite.id, roles: %w[finance]}
          }
        )

        expect(result["errors"].first["message"]).to eq("Resource not found")
        expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
        expect(result["errors"].first["extensions"]["details"]["invite"]).to eq(["not_found"])
      end
    end
  end
end
