# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::RevenueStreams::PlansService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/revenue_streams_plans.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/revenue_streams/#{organization.id}/plans/")
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
      it "returns expected revenue streams plans" do
        expect(service_call).to be_success
        expect(service_call.data_revenue_streams_plans["revenue_streams_plans"].count).to eq(4)
        expect(service_call.data_revenue_streams_plans["revenue_streams_plans"].first).to eq(
          {
            "plan_id" => "8d39f27f-8371-43ea-a327-c9579e70eeb3",
            "amount_currency" => "EUR",
            "plan_code" => "custom_plan_penny",
            "plan_deleted_at" => nil,
            "customers_count" => 1,
            "gross_revenue_amount_cents" => 120735293,
            "net_revenue_amount_cents" => 120735293,
            "organization_id" => "2537afc4-0e7c-4abb-89b7-d9b28c35780b",
            "plan_name" => "Penny",
            "plan_interval" => "monthly",
            "customers_share" => 0.0055,
            "gross_revenue_share" => 0.1148,
            "net_revenue_share" => 0.1148
          }
        )
        expect(service_call.data_revenue_streams_plans["meta"]).to eq(
          {
            "current_page" => 1,
            "next_page" => 2,
            "prev_page" => 0,
            "total_count" => 100,
            "total_pages" => 5
          }
        )
      end
    end
  end
end
