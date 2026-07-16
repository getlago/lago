# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentMethods::GenerateCheckoutUrl do
  let(:required_permission) { "payment_methods:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider, organization:) }
  let(:user) { membership.user }
  let(:payment_method) { create(:payment_method, customer:, organization:, is_default: true) }

  let(:mutation) do
    <<-GQL
      mutation($input: GenerateCheckoutUrlInput!) {
        generateCheckoutUrl(input: $input) {
          checkoutUrl
        }
      }
    GQL
  end

  before do
    payment_method

    create(
      :stripe_customer,
      customer_id: customer.id,
      payment_provider: stripe_provider
    )

    customer.update!(payment_provider: "stripe", payment_provider_code: stripe_provider.code)

    allow(::Stripe::Checkout::Session).to receive(:create)
      .and_return({"url" => "https://example.com"})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payment_methods:create"

  context "with valid preconditions" do
    it "returns the checkout url" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {customerId: customer.id}
        }
      )

      data = result["data"]["generateCheckoutUrl"]

      expect(data["checkoutUrl"]).to eq("https://example.com")
    end
  end

  context "when customer is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: "foo_bar"
          }
        }
      )

      expect_not_found(result)
    end
  end
end
