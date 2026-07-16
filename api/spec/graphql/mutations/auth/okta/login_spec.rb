# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Auth::Okta::Login, :premium, cache: :memory do
  let(:okta_integration) { create(:okta_integration, domain: "bar.com", organization_name: "foo") }
  let(:lago_http_client) { instance_double(LagoHttpClient::Client) }
  let(:okta_token_response) { OpenStruct.new(body: {access_token: "access_token"}) }
  let(:okta_userinfo_response) { OpenStruct.new({email: "foo@bar.com"}) }
  let(:state) { SecureRandom.uuid }

  let(:mutation) do
    <<~GQL
      mutation($input: OktaLoginInput!) {
        oktaLogin(input: $input) {
          user {
            email
          }
          token
        }
      }
    GQL
  end

  before do
    okta_integration

    if okta_integration
      okta_integration.organization.premium_integrations << "okta"
      okta_integration.organization.save!
      okta_integration.organization.enable_okta_authentication!
    end

    Rails.cache.write(state, "foo@bar.com")

    allow(LagoHttpClient::Client).to receive(:new).and_return(lago_http_client)
    allow(lago_http_client).to receive(:post_url_encoded).and_return(okta_token_response)
    allow(lago_http_client).to receive(:get).and_return(okta_userinfo_response)
  end

  it "returns logged user" do
    result = execute_graphql(
      query: mutation,
      variables: {
        input: {
          state:,
          code: "code"
        }
      }
    )

    response = result["data"]["oktaLogin"]

    expect(response["user"]["email"]).to eq("foo@bar.com")
    expect(response["token"]).to be_present
  end

  context "when email domain is not configured with an integration" do
    let(:okta_integration) { nil }

    it "returns an error" do
      result = execute_graphql(
        query: mutation,
        variables: {
          input: {
            state:,
            code: "code"
          }
        }
      )

      response = result["errors"].first["extensions"]

      expect(response["status"]).to eq(422)
      expect(response["details"]["base"]).to include("domain_not_configured")
    end
  end
end
