# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::PrepaidCreditsService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/prepaid_credits.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/prepaid_credits/#{organization.id}/")
      .to_return(status: 200, body: body_response, headers: {})
  end

  describe "#call" do
    subject(:service_call) { service.call }

    context "when licence is not premium" do
      it "returns an error" do
        expect(service_call).not_to be_success
        expect(service_call.error.code).to eq("feature_unavailable")
      end
    end

    context "when licence is premium", :premium do
      it "returns expected prepaid credits" do
        expect(service_call).to be_success
        expect(service_call.prepaid_credits.count).to eq(3)
        expect(service_call.prepaid_credits.first).to eq(
          {
            "organization_id" => "5e6eb312-1e25-40d7-83b8-4ee117b74255",
            "start_of_period_dt" => "2023-12-01",
            "end_of_period_dt" => "2023-12-31",
            "amount_currency" => "EUR",
            "purchased_amount" => 0.0,
            "offered_amount" => 0.0,
            "consumed_amount" => 120.45,
            "voided_amount" => 0.0,
            "purchased_credits_quantity" => 0.0,
            "offered_credits_quantity" => 0.0,
            "consumed_credits_quantity" => 120.45,
            "voided_credits_quantity" => 0.0
          }
        )
      end
    end
  end
end
