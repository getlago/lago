# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvitesResolver do
  let(:query) do
    <<~GQL
      query {
        invites(limit: 5) {
          collection { id }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invite) { create(:invite, organization:) }

  it "returns a list of invites" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: invite.organization,
      query:
    )

    invites_response = result["data"]["invites"]

    expect(invites_response["collection"].count).to eq(organization.invites.count)
    expect(invites_response["collection"].first["id"]).to eq(invite.id)

    expect(invites_response["metadata"]["currentPage"]).to eq(1)
    expect(invites_response["metadata"]["totalCount"]).to eq(1)
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        query:
      )

      expect_graphql_error(
        result:,
        message: "Missing organization id"
      )
    end
  end
end
