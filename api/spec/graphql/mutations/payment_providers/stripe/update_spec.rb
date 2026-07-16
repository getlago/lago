# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Stripe::Update do
  let(:required_permission) { "organization:integrations:update" }
  let(:membership) { create(:membership) }
  let(:stripe_provider) { create(:stripe_provider, organization: membership.organization) }
  let(:success_redirect_url) { Faker::Internet.url }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateStripePaymentProviderInput!) {
        updateStripePaymentProvider(input: $input) {
          id
          successRedirectUrl
          supports3ds
        }
      }
    GQL
  end

  before { stripe_provider }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:update"

  it "updates an stripe provider" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      # You wouldn't have `create` without `view` permission
      # `view` is necessary to retrieve the created record in the response
      permissions: [required_permission, "organization:integrations:view"],
      query: mutation,
      variables: {
        input: {
          id: stripe_provider.id,
          successRedirectUrl: success_redirect_url,
          supports3ds: true
        }
      }
    )

    result_data = result["data"]["updateStripePaymentProvider"]

    expect(result_data["successRedirectUrl"]).to eq(success_redirect_url)
    expect(result_data["supports3ds"]).to eq(true)
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
            id: stripe_provider.id,
            successRedirectUrl: nil
          }
        }
      )

      result_data = result["data"]["updateStripePaymentProvider"]

      expect(result_data["successRedirectUrl"]).to eq(nil)
    end
  end
end
