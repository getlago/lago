# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::RevenueStreamsResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $externalCustomerId: String) {
        dataApiRevenueStreams(currency: $currency, externalCustomerId: $externalCustomerId) {
          collection {
            amountCurrency
            couponsAmountCents
            grossRevenueAmountCents
            netRevenueAmountCents
            commitmentFeeAmountCents
            oneOffFeeAmountCents
            subscriptionFeeAmountCents
            usageBasedFeeAmountCents
            startOfPeriodDt
            endOfPeriodDt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/revenue_streams.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/revenue_streams/#{organization.id}/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of revenue streams" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    revenue_streams_response = result["data"]["dataApiRevenueStreams"]
    expect(revenue_streams_response["collection"].first).to include(
      {
        "startOfPeriodDt" => "2024-01-01",
        "endOfPeriodDt" => "2024-01-31"
      }
    )
  end
end
