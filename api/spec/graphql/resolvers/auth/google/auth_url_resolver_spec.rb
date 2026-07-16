# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Auth::Google::AuthUrlResolver do
  let(:query) do
    <<~GQL
      query {
        googleAuthUrl {
          url
        }
      }
    GQL
  end

  before do
    ENV["GOOGLE_AUTH_CLIENT_ID"] = "client_id"
    ENV["GOOGLE_AUTH_CLIENT_SECRET"] = "client_secret"
  end

  it "returns the google auth url" do
    result = execute_graphql(
      query:,
      request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com"))
    )

    response = result["data"]["googleAuthUrl"]

    expect(response["url"]).to include("https://accounts.google.com/o/oauth2/auth")
  end

  context "when google auth is not setup" do
    before do
      ENV["GOOGLE_AUTH_CLIENT_ID"] = nil
      ENV["GOOGLE_AUTH_CLIENT_SECRET"] = nil
    end

    it "returns an error" do
      result = execute_graphql(
        query:,
        request: Rack::Request.new(Rack::MockRequest.env_for("http://example.com"))
      )

      response = result["errors"].first

      expect(response["extensions"]["code"]).to eq("google_auth_missing_setup")
      expect(response["extensions"]["status"]).to eq(500)
    end
  end
end
