# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::PaymentMethodsResolver do
  let(:required_permission) { "payment_methods:view" }

  let(:payment_method) { create(:payment_method, customer:, organization:) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  before do
    payment_method
    create(:payment_method, organization:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "payment_methods:view"

  context "when external customer id is present" do
    let(:query) do
      <<~GQL
        query($externalCustomerId: ID!, $withDeleted: Boolean) {
          paymentMethods(externalCustomerId: $externalCustomerId, limit: 5, withDeleted: $withDeleted) {
            collection {
              id
              customer { id }
              isDefault
              paymentProviderCode
              paymentProviderType
              details { brand last4 }
            }
            metadata { currentPage, totalCount }
          }
        }
      GQL
    end

    it "returns a list of payment methods" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          externalCustomerId: customer.external_id
        }
      )

      payments_response = result["data"]["paymentMethods"]

      expect(payments_response["collection"].count).to eq(1)
      expect(payments_response["collection"].first["paymentProviderCode"]).to eq(payment_method.payment_provider.code)
      expect(payments_response["collection"].first["paymentProviderType"]).to eq("stripe")
      expect(payments_response["collection"].first["details"]["brand"]).to eq("Visa")
      expect(payments_response["collection"].first["details"]["last4"]).to eq("9876")
    end

    context "when filtering by with_deleted" do
      let(:deleted_payment_method) { create(:payment_method, customer:, organization:, deleted_at: Time.current) }

      before { deleted_payment_method }

      it "returns all payment_methods including deleted ones" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {
            externalCustomerId: customer.external_id,
            withDeleted: true
          }
        )
        payments_response = result["data"]["paymentMethods"]

        expect(payments_response["collection"].count).to eq(2)
        expect(payments_response["collection"].map { |p| p["id"] }).to include(payment_method.id, deleted_payment_method.id)

        expect(payments_response["metadata"]["currentPage"]).to eq(1)
        expect(payments_response["metadata"]["totalCount"]).to eq(2)
      end
    end
  end
end
