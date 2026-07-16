# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Flutterwave::Create do
  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:secret_key) { "FLWSECK-xxxxxxxxx-X" }
  let(:code) { "flutterwave_1" }
  let(:name) { "Flutterwave 1" }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: AddFlutterwavePaymentProviderInput!) {
        addFlutterwavePaymentProvider(input: $input) {
          id,
          code,
          name,
          secretKey,
          successRedirectUrl,
          webhookSecret
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:create"

  it "creates a flutterwave provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {input: {
        code:,
        name:,
        secretKey: secret_key,
        successRedirectUrl: success_redirect_url
      }}
    )

    result_data = result["data"]["addFlutterwavePaymentProvider"]

    expect(result_data["id"]).to be_present
    expect(result_data["code"]).to eq(code)
    expect(result_data["name"]).to eq(name)
    expect(result_data["secretKey"]).to eq("••••••••…x-X")
    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
    expect(result_data["webhookSecret"]).to be_present
  end
end
