# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Analytics::GrossRevenuesResolver do
  let(:required_permission) { "analytics:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $externalCustomerId: String, $expireCache: Boolean) {
        grossRevenues(currency: $currency, externalCustomerId: $externalCustomerId, expireCache: $expireCache) {
          collection {
            month
            amountCents
            currency
            invoicesCount
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "analytics:view"

  it "returns a list of gross revenues" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    expect(result["data"]["grossRevenues"]["collection"]).to eq([])
  end
end
