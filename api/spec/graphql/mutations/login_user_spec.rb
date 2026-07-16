# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::LoginUser do
  let(:membership) { create(:membership) }
  let(:user) { membership.user }
  let(:mutation) do
    <<~GQL
      mutation($input: LoginUserInput!) {
        loginUser(input: $input) {
          token
          user {
            id
            email
          }
        }
      }
    GQL
  end

  it "returns token and user" do
    result = execute_graphql(
      query: mutation,
      variables: {
        input: {
          email: user.email,
          password: "ILoveLago"
        }
      }
    )

    result_data = result["data"]["loginUser"]

    expect(result_data["token"]).to be_present
    expect(result_data["user"]["id"]).to eq(user.id)
  end

  context "with bad credentials" do
    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        variables: {
          input: {
            email: user.email,
            password: "badpassword"
          }
        }
      )

      expect_unprocessable_entity(result)
      expect(result["errors"].first.dig("extensions", "details").keys).to include("base")
      expect(result["errors"].first.dig("extensions", "details", "base")).to include("incorrect_login_or_password")
    end
  end

  context "with revoked membership" do
    let(:revoked_membership) { create(:membership, status: :revoked) }

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        variables: {
          input: {
            email: revoked_membership.user.email,
            password: "ILoveLago"
          }
        }
      )

      expect_unprocessable_entity(result)
      expect(result["errors"].first.dig("extensions", "details").keys).to include("base")
      expect(result["errors"].first.dig("extensions", "details", "base")).to include("incorrect_login_or_password")
    end
  end
end
