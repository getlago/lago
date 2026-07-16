# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Adyen::Update do
  let(:required_permission) { "organization:integrations:update" }
  let(:membership) { create(:membership) }
  let(:adyen_provider) { create(:adyen_provider, organization: membership.organization) }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateAdyenPaymentProviderInput!) {
        updateAdyenPaymentProvider(input: $input) {
          id,
          successRedirectUrl
        }
      }
    GQL
  end

  before { adyen_provider }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "updates an adyen provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {
        input: {
          id: adyen_provider.id,
          successRedirectUrl: success_redirect_url
        }
      }
    )

    result_data = result["data"]["updateAdyenPaymentProvider"]

    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
  end

  context "when success redirect url is nil" do
    it "removes success redirect url from the provider" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        # You wouldn't have `create` without `view` permission
        # `view` is necessary to retrieve the created record in the response
        permissions: [required_permission, "organization:integrations:view"],
        query: mutation,
        variables: {
          input: {
            id: adyen_provider.id,
            successRedirectUrl: nil
          }
        }
      )

      result_data = result["data"]["updateAdyenPaymentProvider"]

      expect(result_data["successRedirectUrl"]).to eq(nil)
    end
  end
end
