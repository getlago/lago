# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::Analytics::OverdueBalancesResolver do
  let(:query) do
    <<~GQL
      query {
        customerPortalOverdueBalances {
          collection {
            month
            amountCents
            lagoInvoiceIds
            currency
          }
        }
      }
    GQL
  end

  let(:organization) { create(:organization, created_at: DateTime.new(2024, 1, 15)) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:, currency: "USD") }

  it_behaves_like "requires a customer portal user"

  it "returns a list of overdue balances" do
    travel_to(DateTime.new(2024, 2, 10)) do
      create(:invoice, organization:, customer:, total_amount_cents: 1000, currency: "USD")
      i1 = create(:invoice, organization:, customer:, total_amount_cents: 2000, currency: "USD", payment_overdue: true)
      i2 = create(:invoice, organization:, customer:, total_amount_cents: 2000, currency: "USD", payment_overdue: true)

      result = execute_graphql(customer_portal_user: customer, query:)
      overdue_balances_response = result["data"]["customerPortalOverdueBalances"]

      expect(overdue_balances_response["collection"]).to contain_exactly(
        "month" => include("2024-02-01"),
        "currency" => "USD",
        "amountCents" => "4000",
        "lagoInvoiceIds" => contain_exactly(i1.id, i2.id)
      )
    end
  end
end
