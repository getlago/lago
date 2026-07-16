# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::OrderResolver do
  let(:required_permission) { "orders:view" }

  let(:query) do
    <<~GQL
      query($id: ID!) {
        order(id: $id) {
          id
          number
          status
          orderType
          createdAt
          updatedAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:order_form) { create(:order_form, :signed, organization:, customer:, quote:) }
  let(:order) { create(:order, organization:, customer:, order_form:) }

  before { order }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "orders:view"

  it "returns a single order" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {id: order.id}
    )

    data = result["data"]["order"]

    expect(data["id"]).to eq(order.id)
    expect(data["number"]).to eq(order.number)
    expect(data["status"]).to eq("created")
    expect(data["orderType"]).to eq("subscription_creation")
  end

  context "when order is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: SecureRandom.uuid}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
