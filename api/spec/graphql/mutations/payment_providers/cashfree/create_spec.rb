# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Cashfree::Create do
  let(:required_permission) { "organization:integrations:create" }
  let(:membership) { create(:membership) }
  let(:client_id) { "123456_abc" }
  let(:client_secret) { "cfsk_ma_prod_abc_123456" }
  let(:code) { "cashfree_1" }
  let(:name) { "Cashfree 1" }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: AddCashfreePaymentProviderInput!) {
        addCashfreePaymentProvider(input: $input) {
          id,
          code,
          name,
          clientId,
          clientSecret
          successRedirectUrl
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:create"

  it "creates a cashfree provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {
        input: {
          code:,
          name:,
          clientId: client_id,
          clientSecret: client_secret,
          successRedirectUrl: success_redirect_url
        }
      }
    )

    result_data = result["data"]["addCashfreePaymentProvider"]

    expect(result_data["id"]).to be_present
    expect(result_data["code"]).to eq(code)
    expect(result_data["name"]).to eq(name)
    expect(result_data["clientId"]).to eq(client_id)
    expect(result_data["clientSecret"]).to eq(client_secret)
    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
  end
end
