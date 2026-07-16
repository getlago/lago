# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PasswordResetResolver do
  let(:query) do
    <<~GQL
      query($token: String!) {
        passwordReset(token: $token) {
          id
          user {
            id
            email
          }
        }
      }
    GQL
  end

  let(:password_reset) { create(:password_reset) }

  it "returns a single password reset" do
    result = execute_graphql(
      query:,
      variables: {
        token: password_reset.token
      }
    )

    data = result["data"]["passwordReset"]

    expect(data["id"]).to eq(password_reset.id)
    expect(data["user"]["email"]).to eq(password_reset.user.email)
  end

  context "when password reset is not found" do
    it "returns an error" do
      result = execute_graphql(
        query:,
        variables: {
          token: "foo"
        }
      )

      expect_graphql_error(
        result:,
        message: "Resource not found"
      )
    end
  end
end
