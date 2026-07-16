# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::Usages::ForecastedResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query {
        dataApiUsagesForecasted {
          collection {
            amountCurrency
            amountCents
            amountCentsForecastConservative
            amountCentsForecastRealistic
            amountCentsForecastOptimistic
            units
            unitsForecastConservative
            unitsForecastRealistic
            unitsForecastOptimistic
            endOfPeriodDt
            startOfPeriodDt
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages_forecasted.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/forecasted/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of forecasted usages" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    forecasted_response = result["data"]["dataApiUsagesForecasted"]
    expect(forecasted_response["collection"].first).to include(
      {
        "amountCents" => "1000",
        "amountCentsForecastConservative" => "1000",
        "amountCentsForecastOptimistic" => "1000",
        "amountCentsForecastRealistic" => "1000",
        "amountCurrency" => "EUR",
        "endOfPeriodDt" => "2025-06-28",
        "startOfPeriodDt" => "2025-06-27",
        "units" => 100.0,
        "unitsForecastConservative" => 100.0,
        "unitsForecastOptimistic" => 100.0,
        "unitsForecastRealistic" => 100.0
      }
    )
  end
end
