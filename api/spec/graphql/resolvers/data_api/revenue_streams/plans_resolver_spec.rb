# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::RevenueStreams::PlansResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $orderBy: OrderByEnum, $limit: Int, $page: Int) {
        dataApiRevenueStreamsPlans(currency: $currency, orderBy: $orderBy, limit: $limit, page: $page) {
          collection {
            planCode
            planDeletedAt
            planId
            planInterval
            planName
            customersCount
            customersShare
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
  let(:body_response) { File.read("spec/fixtures/lago_data_api/revenue_streams_plans.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/revenue_streams/#{organization.id}/plans/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of revenue streams plans" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    revenue_streams_response = result["data"]["dataApiRevenueStreamsPlans"]
    expect(revenue_streams_response["collection"].first).to include(
      {
        "planId" => "8d39f27f-8371-43ea-a327-c9579e70eeb3",
        "amountCurrency" => "EUR",
        "planCode" => "custom_plan_penny",
        "planDeletedAt" => nil,
        "customersCount" => 1,
        "grossRevenueAmountCents" => "120735293",
        "netRevenueAmountCents" => "120735293",
        "planName" => "Penny",
        "planInterval" => "monthly",
        "customersShare" => 0.0055,
        "grossRevenueShare" => 0.1148,
        "netRevenueShare" => 0.1148
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
