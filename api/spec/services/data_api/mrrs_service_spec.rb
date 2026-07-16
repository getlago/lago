# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::MrrsService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/mrrs.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/mrrs/#{organization.id}/")
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
      it "returns expected mrrs" do
        expect(service_call).to be_success
        expect(service_call.mrrs.count).to eq(4)
        expect(service_call.mrrs.first).to eq(
          {
            "organization_id" => "2537afc4-0e7c-4abb-89b7-d9b28c35780b",
            "start_of_period_dt" => "2023-11-01",
            "end_of_period_dt" => "2023-11-30",
            "amount_currency" => "EUR",
            "starting_mrr" => 0,
            "ending_mrr" => 23701746,
            "mrr_new" => 25016546,
            "mrr_expansion" => 0,
            "mrr_contraction" => 0,
            "mrr_churn" => -1314800,
            "mrr_change" => 23701746
          }
        )
      end
    end
  end
end
