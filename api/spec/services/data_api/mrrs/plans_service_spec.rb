# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::Mrrs::PlansService do
  let(:service) { described_class.new(organization, **params) }
  let(:customer) { create(:customer, organization:) }
  let(:organization) { create(:organization) }
  let(:body_response) { File.read("spec/fixtures/lago_data_api/mrrs_plans.json") }
  let(:params) { {} }

  before do
    stub_request(:get, "#{ENV["LAGO_DATA_API_URL"]}/mrrs/#{organization.id}/plans/")
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
      it "returns expected mrrs plans" do
        expect(service_call).to be_success
        expect(service_call.data_mrrs_plans["mrrs_plans"].count).to eq(4)
        expect(service_call.data_mrrs_plans["mrrs_plans"].first).to eq(
          {
            "dt" => "2025-02-25",
            "amount_currency" => "EUR",
            "plan_id" => "8f550d3e-1234-4f4d-a752-61b0f98a9ef7",
            "active_customers_count" => 1,
            "mrr" => 1000000.0,
            "mrr_share" => 0.0279,
            "plan_name" => "Tondr",
            "organization_id" => "2537afc4-0e7c-4abb-89b7-d9b28c35780b",
            "plan_code" => "custom_plan_tondr",
            "plan_deleted_at" => nil,
            "plan_interval" => "monthly",
            "active_customers_share" => 0.009
          }
        )
        expect(service_call.data_mrrs_plans["meta"]).to eq(
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
