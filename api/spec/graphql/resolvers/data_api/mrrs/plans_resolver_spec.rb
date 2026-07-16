# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::Mrrs::PlansResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $limit: Int, $page: Int) {
        dataApiMrrsPlans(currency: $currency, limit: $limit, page: $page) {
          collection {
            amountCurrency
            dt
            planCode
            planDeletedAt
            planId
            planInterval
            planName
            activeCustomersCount
            activeCustomersShare
            mrr
            mrrShare
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
  let(:body_response) { File.read("spec/fixtures/lago_data_api/mrrs_plans.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/mrrs/#{organization.id}/plans/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of mrrs plans" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    mrrs_response = result["data"]["dataApiMrrsPlans"]
    expect(mrrs_response["collection"].first).to include(
      {
        "dt" => "2025-02-25",
        "amountCurrency" => "EUR",
        "planId" => "8f550d3e-1234-4f4d-a752-61b0f98a9ef7",
        "activeCustomersCount" => "1",
        "mrr" => 1000000.0,
        "mrrShare" => 0.0279,
        "planName" => "Tondr",
        "planCode" => "custom_plan_tondr",
        "planDeletedAt" => nil,
        "planInterval" => "monthly",
        "activeCustomersShare" => 0.009
      }
    )
    expect(mrrs_response["metadata"]).to include(
      "currentPage" => 1,
      "nextPage" => 2,
      "prevPage" => 0,
      "totalCount" => 100,
      "totalPages" => 5
    )
  end
end
