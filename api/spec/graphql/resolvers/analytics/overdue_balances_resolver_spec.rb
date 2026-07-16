# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Analytics::OverdueBalancesResolver do
  let(:required_permission) { "analytics:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $externalCustomerId: String, $months: Int, $expireCache: Boolean) {
        overdueBalances(currency: $currency, externalCustomerId: $externalCustomerId, months: $months, expireCache: $expireCache) {
          collection {
            amountCents
            currency
            lagoInvoiceIds
            month
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

  it "returns a list of overdue balances" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    expect(result["data"]["overdueBalances"]["collection"]).to eq([])
  end
end
