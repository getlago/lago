# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::UsagesResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum, $externalCustomerId: String, $billingEntityCode: String) {
        dataApiUsages(currency: $currency, externalCustomerId: $externalCustomerId, billingEntityCode: $billingEntityCode) {
          collection {
            amountCurrency
            amountCents
            billableMetricCode
            units
            startOfPeriodDt
            endOfPeriodDt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages.json") }
  let(:params) { {time_granularity: "daily", billing_entity_code: "code"} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/")
      .with(query: params)
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of usages" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {billingEntityCode: "code"}
    )

    usages_response = result["data"]["dataApiUsages"]
    expect(usages_response["collection"].first).to include(
      {
        "startOfPeriodDt" => "2024-01-01",
        "endOfPeriodDt" => "2024-01-31"
      }
    )
  end
end
