# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Adyen::Create do
  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:api_key) { "api_key_123456_abc" }
  let(:hmac_key) { "hmac_124" }
  let(:code) { "adyen_1" }
  let(:name) { "Adyen 1" }
  let(:live_prefix) { "test" }
  let(:merchant_account) { "Merchant1" }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: AddAdyenPaymentProviderInput!) {
        addAdyenPaymentProvider(input: $input) {
          id,
          apiKey,
          code,
          name,
          hmacKey,
          livePrefix,
          merchantAccount,
          successRedirectUrl
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:create"

  it "creates an adyen provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {
        input: {
          apiKey: api_key,
          hmacKey: hmac_key,
          code:,
          name:,
          merchantAccount: merchant_account,
          livePrefix: live_prefix,
          successRedirectUrl: success_redirect_url
        }
      }
    )

    result_data = result["data"]["addAdyenPaymentProvider"]

    expect(result_data["id"]).to be_present
    expect(result_data["apiKey"]).to eq("••••••••…abc")
    expect(result_data["hmacKey"]).to eq("••••••••…124")
    expect(result_data["code"]).to eq(code)
    expect(result_data["name"]).to eq(name)
    expect(result_data["livePrefix"]).to eq(live_prefix)
    expect(result_data["merchantAccount"]).to eq(merchant_account)
    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
  end
end
