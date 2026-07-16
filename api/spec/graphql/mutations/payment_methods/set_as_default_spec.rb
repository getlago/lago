# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentMethods::SetAsDefault do
  let(:required_permission) { "payment_methods:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:user) { membership.user }
  let(:payment_method) { create(:payment_method, customer:, organization:, is_default: false) }
  let(:payment_method2) { create(:payment_method, customer:, organization:, is_default: true) }
  let(:payment_method3) { create(:payment_method, customer:, organization:, is_default: false) }

  let(:mutation) do
    <<-GQL
      mutation($input: SetAsDefaultInput!) {
        setPaymentMethodAsDefault(input: $input) {
          id
        }
      }
    GQL
  end

  before do
    payment_method
    payment_method2
    payment_method3
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payment_methods:update"

  context "with valid preconditions" do
    it "returns the payment method after setting it as default" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: payment_method.id}
        }
      )

      data = result["data"]["setPaymentMethodAsDefault"]

      expect(data["id"]).to eq(payment_method.id)
      expect(payment_method.reload.is_default).to eq(true)
      expect(payment_method2.reload.is_default).to eq(false)
      expect(payment_method3.reload.is_default).to eq(false)
    end
  end

  context "when payment method is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: "foo_bar"
          }
        }
      )

      expect_not_found(result)
    end
  end
end
