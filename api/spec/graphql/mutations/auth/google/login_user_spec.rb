# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Auth::Google::LoginUser do
  let(:membership) { create(:membership) }
  let(:user) { membership.user }
  let(:google_service) { instance_double(Auth::GoogleService) }

  let(:login_result) do
    result = BaseService::Result.new
    result.user = user
    result.token = "token"
    result
  end

  let(:mutation) do
    <<~GQL
      mutation($input: GoogleLoginUserInput!) {
        googleLoginUser(input: $input) {
          token
          user {
            id
            email
          }
        }
      }
    GQL
  end

  before do
    allow(Auth::GoogleService).to receive(:new).and_return(google_service)
    allow(google_service).to receive(:login).and_return(login_result)
  end

  it "returns token and user" do
    result = execute_graphql(
      query: mutation,
      request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
      variables: {
        input: {
          code: "code"
        }
      }
    )

    response = result["data"]["googleLoginUser"]

    expect(response["token"]).to eq("token")
    expect(response["user"]["id"]).to eq(user.id)
    expect(response["user"]["email"]).to eq(user.email)
  end

  context "when user does not exist" do
    let(:login_result) do
      result = BaseService::Result.new
      result.single_validation_failure!(error_code: "user_does_not_exist")
      result
    end

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
        variables: {
          input: {
            code: "code"
          }
        }
      )

      response = result["errors"].first

      expect(response["extensions"]["status"]).to eq(422)
      expect(response["message"]).to eq("Unprocessable Entity")
    end
  end
end
