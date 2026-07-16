# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::SubscriptionResolver do
  let(:query) do
    <<~GQL
      query($subscriptionId: ID!) {
        customerPortalSubscription(id: $subscriptionId) {
          id
          name
          startedAt
          endingAt
          plan {
            id
            code
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:) }

  before do
    customer
  end

  it_behaves_like "requires a customer portal user"

  it "returns a single subscription" do
    result = execute_graphql(
      customer_portal_user: customer,
      query:,
      variables: {subscriptionId: subscription.id}
    )

    subscription_response = result["data"]["customerPortalSubscription"]
    expect(subscription_response).to include(
      "id" => subscription.id,
      "name" => subscription.name,
      "startedAt" => subscription.started_at.iso8601,
      "endingAt" => subscription.ending_at
    )

    expect(subscription_response["plan"]).to include(
      "id" => subscription.plan.id,
      "code" => subscription.plan.code
    )
  end

  context "when subscription is not found" do
    it "returns an error" do
      result = execute_graphql(
        customer_portal_user: customer,
        query:,
        variables: {subscriptionId: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
