# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Gocardless::Update do
  let(:required_permission) { "organization:integrations:update" }
  let(:oauth_client) { instance_double(OAuth2::Client) }
  let(:auth_code_strategy) { instance_double(OAuth2::Strategy::AuthCode) }
  let(:access_token) { instance_double(OAuth2::AccessToken) }
  let(:membership) { create(:membership) }
  let(:gocardless_provider) { create(:gocardless_provider, organization: membership.organization) }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateGocardlessPaymentProviderInput!) {
        updateGocardlessPaymentProvider(input: $input) {
          id,
          successRedirectUrl
        }
      }
    GQL
  end

  before do
    allow(OAuth2::Client).to receive(:new)
      .and_return(oauth_client)
    allow(oauth_client).to receive(:auth_code)
      .and_return(auth_code_strategy)
    allow(auth_code_strategy).to receive(:get_token)
      .and_return(access_token)
    allow(access_token).to receive(:token)
      .and_return("access_token_554")

    gocardless_provider
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "updates an gocardless provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {
        input: {
          id: gocardless_provider.id,
          successRedirectUrl: success_redirect_url
        }
      }
    )

    result_data = result["data"]["updateGocardlessPaymentProvider"]

    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
  end

  context "when success redirect url is nil" do
    it "removes success redirect url from the provider" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: gocardless_provider.id,
            successRedirectUrl: nil
          }
        }
      )

      result_data = result["data"]["updateGocardlessPaymentProvider"]

      expect(result_data["successRedirectUrl"]).to eq(nil)
    end
  end
end
