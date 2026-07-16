# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::DataApi::Usages::InvoicedResolver, :premium do
  let(:required_permission) { "data_api:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum) {
        dataApiUsagesInvoiced(currency: $currency) {
          collection {
            startOfPeriodDt
            endOfPeriodDt
            billableMetricCode
            amountCents
            amountCurrency
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages_invoiced.json") }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/invoiced/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "data_api:view"

  it "returns a list of usages invoiced" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    usages_invoiced_response = result["data"]["dataApiUsagesInvoiced"]
    expect(usages_invoiced_response["collection"].first).to include(
      {
        "startOfPeriodDt" => "2024-01-01",
        "endOfPeriodDt" => "2024-01-31",
        "billableMetricCode" => "account_members",
        "amountCurrency" => "EUR",
        "amountCents" => "26600"
      }
    )
  end
end
