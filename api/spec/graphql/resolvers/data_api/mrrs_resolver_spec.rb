# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::MrrsResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum) {
        dataApiMrrs(currency: $currency) {
          collection {
            amountCurrency
            startingMrr
            endingMrr
            mrrNew
            mrrExpansion
            mrrContraction
            mrrChurn
            mrrChange
            startOfPeriodDt
            endOfPeriodDt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/mrrs.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/mrrs/#{organization.id}/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of mrrs" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    mrrs_response = result["data"]["dataApiMrrs"]
    expect(mrrs_response["collection"].first).to eq(
      {
        "startOfPeriodDt" => "2023-11-01",
        "endOfPeriodDt" => "2023-11-30",
        "amountCurrency" => "EUR",
        "startingMrr" => "0",
        "endingMrr" => "23701746",
        "mrrNew" => "25016546",
        "mrrExpansion" => "0",
        "mrrContraction" => "0",
        "mrrChurn" => "-1314800",
        "mrrChange" => "23701746"
      }
    )
  end
end
