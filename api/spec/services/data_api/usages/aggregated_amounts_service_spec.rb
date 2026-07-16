# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::Usages::AggregatedAmountsService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/usages_aggregated_amounts.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/usages/#{organization.id}/aggregated_amounts/")
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
      it "returns expected aggregated amounts usage" do
        expect(service_call).to be_success
        expect(service_call.aggregated_amounts_usages.count).to eq(3)
        expect(service_call.aggregated_amounts_usages.first).to eq(
          {
            "start_of_period_dt" => "2024-01-01",
            "end_of_period_dt" => "2024-01-31",
            "amount_currency" => "EUR",
            "amount_cents" => 26600
          }
        )
      end
    end
  end
end
