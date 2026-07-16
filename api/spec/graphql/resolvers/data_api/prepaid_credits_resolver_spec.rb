# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::PrepaidCreditsResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $externalCustomerId: String) {
        dataApiPrepaidCredits(currency: $currency, externalCustomerId: $externalCustomerId) {
          collection {
            amountCurrency
            consumedAmount
            offeredAmount
            purchasedAmount
            voidedAmount
            consumedCreditsQuantity
            offeredCreditsQuantity
            purchasedCreditsQuantity
            voidedCreditsQuantity
            startOfPeriodDt
            endOfPeriodDt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/prepaid_credits.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/prepaid_credits/#{organization.id}/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of prepaid credits" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    prepaid_credits_response = result["data"]["dataApiPrepaidCredits"]
    expect(prepaid_credits_response["collection"].first).to include(
      {
        "startOfPeriodDt" => "2023-12-01",
        "endOfPeriodDt" => "2023-12-31",
        "amountCurrency" => "EUR"
      }
    )
  end
end
