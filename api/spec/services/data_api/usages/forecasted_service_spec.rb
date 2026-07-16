# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::Usages::ForecastedService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages_forecasted.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/forecasted/")
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
      it "returns expected forecasted usage" do
        expect(service_call).to be_success
        expect(service_call.forecasted_usages.count).to eq(1)
        eq(
          {
            "start_of_period_dt" => "2025-06-27T06:46:28.300Z",
            "end_of_period_dt" => "2025-06-28T06:46:28.300Z",
            "amount_currency" => "EUR",
            "units" => 100,
            "amount_cents" => 1000,
            "units_forecast_conservative" => 100,
            "units_forecast_realistic" => 100,
            "units_forecast_optimistic" => 100,
            "amount_cents_forecast_conservative" => 1000,
            "amount_cents_forecast_realistic" => 1000,
            "amount_cents_forecast_optimistic" => 1000
          }
        )
      end
    end
  end

  describe "#action_path" do
    subject(:service_path) { service.send(:action_path) }

    it "returns the correct forecasted path" do
      expect(service_path).to eq("usages/#{organization.id}/forecasted/")
    end
  end
end
