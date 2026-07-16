# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invites::Revoke do
  let(:required_permission) { "organization:members:delete" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:user) { membership.user }

  let(:mutation) do
    <<-GQL
      mutation($input: RevokeInviteInput!) {
        revokeInvite(input: $input) {
          id
          status
          revokedAt
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:members:delete"

  describe "Invite revoke mutation" do
    context "with an existing invite" do
      let(:invite) { create(:invite, organization:) }

      it "returns the revoked invite" do
        result = execute_graphql(
          current_organization: organization,
          current_user: user,
          permissions: required_permission,
          query: mutation,
          variables: {
            input: {id: invite.id}
          }
        )

        data = result["data"]["revokeInvite"]

        expect(data["id"]).to eq(invite.id)
        expect(data["status"]).to eq("revoked")
        expect(data["revokedAt"]).to be_present
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
            input: {id: invite.id}
          }
        )

        expect(result["errors"].first["message"]).to eq("Resource not found")
        expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
        expect(result["errors"].first["extensions"]["details"]["invite"]).to eq(["not_found"])
      end
    end
  end
end
