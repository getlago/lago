# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CurrentUserResolver do
  let(:admin_role) { create(:role, :admin) }

  let(:query) do
    <<~GRAPHQL
      query {
        currentUser {
          id
          email
          premium
          memberships {
            roles
            status
            organization {
              name
            }
          }
        }
      }
    GRAPHQL
  end

  it "returns current_user" do
    user = create(:user)
    membership = create(:membership, user:)
    create(:membership_role, membership:, role: admin_role)

    result = execute_graphql(
      current_user: user,
      query:
    )

    expect(result["data"]["currentUser"]["email"]).to eq(user.email)
    expect(result["data"]["currentUser"]["id"]).to eq(user.id)
    expect(result["data"]["currentUser"]["premium"]).to be_falsey
    expect(result["data"]["currentUser"]["memberships"][0]["roles"]).to eq ["Admin"]
    expect(result["data"]["currentUser"]["memberships"][0]["organization"]["name"]).not_to be_empty
  end

  it "returns null for deprecated role field when using custom role" do
    membership = create(:membership)
    custom_role = create(:role, name: "Developer", organization: membership.organization, permissions: %w[organization:view])
    create(:membership_role, membership:, role: custom_role)

    result = execute_graphql(current_user: membership.user, query:)

    expect(result["data"]["currentUser"]["memberships"][0]["role"]).to be_nil
    expect(result["data"]["currentUser"]["memberships"][0]["roles"]).to eq(["Developer"])
  end

  describe "with organizations instead of memberships" do
    let(:query) do
      <<~GRAPHQL
        query {
          currentUser {
            id
            email
            premium
            organizations {
              id
            }
          }
        }
      GRAPHQL
    end

    it "returns organizations" do
      organization = create(:organization)
      membership = create(:membership, organization:)
      result = execute_graphql(
        current_user: membership.user,
        query:
      )

      expect(result["data"]["currentUser"]["organizations"][0]["id"]).to eq organization.id
    end
  end

  describe "with revoked membership" do
    let(:membership) { create(:membership) }
    let(:revoked_membership) do
      create(:membership, user: membership.user, status: :revoked)
    end

    before do
      create(:membership_role, membership:, role: admin_role)
      revoked_membership
    end

    it "only lists organizations when membership has an active status" do
      result = execute_graphql(
        current_user: membership.user,
        query:
      )

      expect(result["data"]["currentUser"]["memberships"]).not_to include(revoked_membership)
    end
  end

  context "with no current_user" do
    it "returns an error" do
      result = execute_graphql(query:)

      expect_unauthorized_error(result)
    end
  end
end
