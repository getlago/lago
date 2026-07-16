# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PasswordResets::Reset do
  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:, user: create(:user, password: "HelloLago!1")) }
  let(:user) { membership.user }
  let(:password_reset) { create(:password_reset, user:) }

  let(:mutation) do
    <<~GQL
      mutation($input: ResetPasswordInput!) {
        resetPassword(input: $input) {
          token
        }
      }
    GQL
  end

  context "with a valid token" do
    subject(:result) do
      execute_graphql(
        query: mutation,
        variables: {
          input: {
            newPassword: "HelloLago!2",
            token: password_reset.token
          }
        }
      )
    end

    it "returns the auth token after a password reset" do
      data = result["data"]["resetPassword"]

      expect(data["token"]).to be_present
    end

    it_behaves_like "produces a security log", "user.password_edited" do
      before { result }
    end
  end

  context "when the password reset is expired" do
    let(:expired_password_reset) do
      create(:password_reset, user:, expire_at: Time.current - 1.minute)
    end

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        variables: {
          input: {
            newPassword: "HelloLago!3",
            token: expired_password_reset.token
          }
        }
      )

      expect_not_found(result)
    end
  end
end
