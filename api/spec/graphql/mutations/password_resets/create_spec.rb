# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PasswordResets::Create do
  include_context "with mocked security logger"

  let(:organization) { create(:organization) }
  let(:membership) { create(:membership, organization:) }
  let(:user) { membership.user }
  let(:email) { user.email }

  let(:mutation) do
    <<~GQL
      mutation($input: CreatePasswordResetInput!) {
        createPasswordReset(input: $input) {
          id
        }
      }
    GQL
  end

  context "with a valid user" do
    subject(:result) do
      execute_graphql(
        query: mutation,
        variables: {
          input: {
            email:
          }
        }
      )
    end

    it "creates a password reset for a user" do
      data = result["data"]["createPasswordReset"]

      expect(data["id"]).to be_present
    end

    it_behaves_like "produces a security log", "user.password_reset_requested" do
      before { result }
    end
  end
end
