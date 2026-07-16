# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::RevenueStreams::CustomersResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $orderBy: OrderByEnum, $limit: Int, $page: Int) {
        dataApiRevenueStreamsCustomers(currency: $currency, orderBy: $orderBy, limit: $limit, page: $page) {
          collection {
            customerId
            customerDeletedAt
            externalCustomerId
            customerName
            amountCurrency
            grossRevenueAmountCents
            grossRevenueShare
            netRevenueAmountCents
            netRevenueShare
          }
          metadata {
            currentPage
            nextPage
            prevPage
            totalCount
            totalPages
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/revenue_streams_customers.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/revenue_streams/#{organization.id}/customers/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of revenue streams customers" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    revenue_streams_response = result["data"]["dataApiRevenueStreamsCustomers"]
    expect(revenue_streams_response["collection"].first).to include(
      {
        "amountCurrency" => "EUR",
        "customerId" => "e4676e50-1234-4606-bcdb-42effbc2b635",
        "customerDeletedAt" => nil,
        "externalCustomerId" => "2537afc4-1234-4abb-89b7-d9b28c35780b",
        "customerName" => "Penny",
        "grossRevenueAmountCents" => "124628322",
        "netRevenueAmountCents" => "124628322",
        "grossRevenueShare" => 0.1185,
        "netRevenueShare" => 0.1185
      }
    )
    expect(revenue_streams_response["metadata"]).to include(
      "currentPage" => 1,
      "nextPage" => 2,
      "prevPage" => 0,
      "totalCount" => 100,
      "totalPages" => 5
    )
  end
end
