# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::CustomerPortal::Analytics::InvoiceCollectionsResolver do
  let(:query) do
    <<~GQL
      query {
        customerPortalInvoiceCollections {
          collection {
            month
            amountCents
            invoicesCount
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

  it "returns a list of invoice collections" do
    travel_to(DateTime.new(2024, 2, 10)) do
      create(:invoice, organization:, customer:, total_amount_cents: 1000, currency: "USD")
      create(:invoice, organization:, customer:, total_amount_cents: 2000, currency: "USD")

      result = execute_graphql(customer_portal_user: customer, query:)
      invoice_collections_response = result["data"]["customerPortalInvoiceCollections"]

      expect(invoice_collections_response["collection"]).to contain_exactly(
        "month" => include("2024-02-01"),
        "currency" => "USD",
        "amountCents" => "3000",
        "invoicesCount" => "2"
      )
    end
  end
end
