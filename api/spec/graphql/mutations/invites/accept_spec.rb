# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invites::Accept do
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:password) { Faker::Internet.password }

  let(:mutation) do
    <<~GQL
      mutation($input: AcceptInviteInput!) {
        acceptInvite(input: $input) {
          token
          user {
            id
            email
          }
        }
      }
    GQL
  end

  describe "Invite revoke mutation" do
    context "with a new user" do
      let(:invite) { create(:invite, organization:) }

      it "accepts the invite" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          query: mutation,
          variables: {
            input: {
              email: invite.email,
              password:,
              token: invite.token
            }
          }
        )

        data = result["data"]["acceptInvite"]

        expect(data["user"]["email"]).to eq(invite.email)
        expect(data["token"]).to be_present

        expect(Auth::TokenService.decode(token: data["token"])).to include("login_method" => "email_password")
      end
    end

    context "when invite is revoked" do
      let(:invite) { create(:invite, organization:, status: :revoked) }

      it "returns an error" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          query: mutation,
          variables: {
            input: {
              email: invite.email,
              password:,
              token: invite.token
            }
          }
        )

        expect(result["errors"].first["extensions"]["status"]).to eq(404)
        expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
        expect(result["errors"].first["extensions"]["details"]["invite"]).to eq(["not_found"])
      end
    end

    context "when invite is already accepted" do
      let(:invite) { create(:invite, organization:, status: :accepted) }

      it "returns an error" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          query: mutation,
          variables: {
            input: {
              email: invite.email,
              password:,
              token: invite.token
            }
          }
        )

        expect(result["errors"].first["extensions"]["status"]).to eq(404)
        expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
        expect(result["errors"].first["extensions"]["details"]["invite"]).to eq(["not_found"])
      end
    end
  end
end
