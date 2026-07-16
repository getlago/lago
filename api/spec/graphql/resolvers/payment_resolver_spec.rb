# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PaymentResolver do
  let(:required_permission) { "payments:view" }

  let(:query) do
    <<~GQL
      query($id: ID!) {
        payment(id: $id) {
          id createdAt updatedAt
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:, fees_amount_cents: 10) }
  let(:payment) { create(:payment, payable: invoice) }

  before { payment }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payments:view"

  it "returns a single payment" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        id: payment.id
      }
    )

    data = result["data"]["payment"]

    expect(data["id"]).to eq(payment.id)
    expect(data["createdAt"]).to eq(payment.created_at.iso8601)
    expect(data["updatedAt"]).to eq(payment.updated_at.iso8601)
  end

  context "when payment is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: invoice.organization,
        permissions: required_permission,
        query:,
        variables: {
          id: "foo"
        }
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
