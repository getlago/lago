# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Auth::Google::RegisterUser do
  let(:google_service) { instance_double(Auth::GoogleService) }
  let(:user) { create(:user) }

  let(:register_user_result) do
    result = BaseService::Result.new
    result.user = user
    result.token = "token"
    result
  end

  let(:mutation) do
    <<~GQL
      mutation($input: GoogleRegisterUserInput!) {
        googleRegisterUser(input: $input) {
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
    allow(google_service).to receive(:register_user).and_return(register_user_result)
  end

  it "returns token and user" do
    result = execute_graphql(
      query: mutation,
      request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
      variables: {
        input: {
          code: "code",
          organizationName: "FooBar"
        }
      }
    )

    response = result["data"]["googleRegisterUser"]

    expect(response["token"]).to eq("token")
    expect(response["user"]["id"]).to be_present
    expect(response["user"]["email"]).to be_present
  end

  context "when user already exists" do
    let(:register_user_result) do
      result = BaseService::Result.new
      result.single_validation_failure!(error_code: "user_already_exists")
      result
    end

    before { user }

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com")),
        variables: {
          input: {
            code: "code",
            organizationName: "FooBar"
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(422)
      expect(response["details"]["base"]).to include("user_already_exists")
    end
  end
end
