# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentProviders::Destroy do
  let(:required_permission) { "organization:integrations:delete" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:payment_provider) { create(:stripe_provider, organization:) }

  let(:mutation) do
    <<-GQL
      mutation($input: DestroyPaymentProviderInput!) {
        destroyPaymentProvider(input: $input) { id }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "organization:integrations:delete"

  it "deletes a payment provider" do
    result = execute_query(
      query: mutation,
      input: {id: payment_provider.id}
    )

    data = result["data"]["destroyPaymentProvider"]
    expect(data["id"]).to eq(payment_provider.id)
  end

  context "when payment provider is not attached to the organization" do
    let(:payment_provider) { create(:stripe_provider) }

    it "returns an error" do
      result = execute_query(
        query: mutation,
        input: {id: payment_provider.id}
      )

      expect(result["errors"].first["message"]).to eq("Resource not found")
      expect(result["errors"].first["extensions"]["code"]).to eq("not_found")
      expect(result["errors"].first["extensions"]["status"]).to eq(404)
    end
  end
end
