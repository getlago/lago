# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentMethods::Destroy do
  let(:required_permissions) { "payment_methods:delete" }
  let(:membership) { create(:membership, organization:) }
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:payment_method) { create(:payment_method, organization:, customer:) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyPaymentMethodInput!) {
        destroyPaymentMethod(input: $input) {
          id
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payment_methods:delete"

  it "deletes a payment method" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permissions,
      query: mutation,
      variables: {
        input: {id: payment_method.id}
      }
    )

    data = result["data"]["destroyPaymentMethod"]
    expect(data["id"]).to eq(payment_method.id)
  end

  context "when payment method is not found" do
    let(:payment_method) { create(:payment_method) }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permissions,
        query: mutation,
        variables: {
          input: {id: payment_method.id}
        }
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
