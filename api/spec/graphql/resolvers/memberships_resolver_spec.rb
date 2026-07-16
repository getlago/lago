# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::MembershipsResolver do
  let(:query) do
    <<~GQL
      query {
        memberships(limit: 5) {
          collection { id }
          metadata { currentPage, totalCount, adminCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership, roles: %i[admin]) }
  let(:organization) { membership.organization }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"

  it "returns a list of memberships" do
    create(:membership, organization: organization, roles: %i[admin])
    create_list(:membership, 2, organization: organization, roles: %i[finance])

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:
    )

    memberships_response = result["data"]["memberships"]

    expect(memberships_response["collection"].count).to eq(4)
    expect(memberships_response["collection"].map { it["id"] }).to include(membership.id)

    expect(memberships_response["metadata"]["currentPage"]).to eq(1)
    expect(memberships_response["metadata"]["totalCount"]).to eq(4)
    expect(memberships_response["metadata"]["adminCount"]).to eq(2)
  end

  it "returns the count of active admin memberships" do
    create(:membership, organization: organization, roles: %i[admin], status: :revoked)
    create_list(:membership, 2, organization: organization, roles: %i[finance])

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:
    )

    expect(result["data"]["memberships"]["metadata"]["adminCount"]).to eq(1)
  end

  describe "traversal attack attempt" do
    let!(:other_org) { create(:organization) }

    let(:other_user) { create(:user) }
    let(:other_user_membership) { create(:membership, user: other_user, organization:) }
    let(:other_user_other_membership) { create(:membership, user: other_user, organization: other_org) }

    let(:query) do
      <<~GQL
        query {
          memberships(limit: 5) {
            collection {
              id
              user {
                organizations {
                  id #{organization_field}
                }
              }
            }
          }
        }
      GQL
    end

    let(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:
      )
    end

    let(:other_org_result_data) do
      result.dig("data", "memberships", "collection")
        &.find { |h| h["id"] == other_user_membership.id }
        &.dig("user", "organizations")
        &.find { |h| h["id"] == other_org.id }
    end

    before do
      other_user
      other_user_membership
      other_user_other_membership
    end

    context "with non-sensitive field" do
      let(:organization_field) { "name" }

      it "allows the query" do
        expect(other_org_result_data).to eq(
          "id" => other_org.id,
          "name" => other_org.name
        )
      end
    end

    context "with sensitive field" do
      let(:organization_field) { "apiKey" }

      it "rejects the query for a sensitive field" do
        expect(other_org_result_data).to be nil
        expect_graphql_error(
          result:,
          message: "Field 'apiKey' doesn't exist on type 'Organization'"
        )
      end
    end
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
