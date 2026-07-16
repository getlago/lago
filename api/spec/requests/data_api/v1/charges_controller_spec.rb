# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataApi::V1::ChargesController do # rubocop:disable Rails/FilePath
  def post_with_data_api_key(path, params = {})
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "X-Data-API-Key" => "test_api_key"
    }
    post(path, params: params.to_json, headers:)
  end
  describe "POST /data_api/v1/charges/bulk_forecasted_usage_amount" do
    subject { post_with_data_api_key("/data_api/v1/charges/bulk_forecasted_usage_amount", params) }

    let(:charge1) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        properties: {amount: "10"}
      )
    end

    let(:charge2) do
      create(
        :standard_charge,
        plan:,
        billable_metric:,
        properties: {amount: "20"}
      )
    end

    let(:charge_filter) { create(:charge_filter, charge: charge1) }
    let(:plan) { create(:plan, organization:, amount_cents: 1000) }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:organization) { create(:organization) }

    let(:params) do
      {
        charges: [
          {
            record_id: 1,
            charge_id: charge1.id,
            charge_filter_id: charge_filter.id,
            units_conservative: 100,
            units_realistic: 500,
            units_optimistic: 1000
          },
          {
            record_id: 2,
            charge_id: charge2.id,
            units_conservative: 200,
            units_realistic: 600,
            units_optimistic: 1200
          }
        ]
      }
    end

    let(:result) do
      BaseService::Result.new.tap do |result|
        result.charge_amount_cents = 10
        result.subscription_amount_cents = 10
        result.total_amount_cents = 20
      end
    end

    before do
      allow(Charges::CalculatePriceService).to receive(:call).and_return(result)
      stub_const("ENV", ENV.to_hash.merge("LAGO_DATA_API_BEARER_TOKEN" => "test_api_key"))
    end

    context "when authenticated and premium", :premium do
      context "when charges are found" do
        it "returns the bulk forecasted usage amounts" do
          subject

          expect(response).to have_http_status(:success)

          json_response = json
          expect(json_response[:results]).to be_an(Array)
          expect(json_response[:results].size).to eq(2)
          expect(json_response[:processed_count]).to eq(2)
          expect(json_response[:failed_count]).to eq(0)
          expect(json_response[:failed_charges]).to be_empty

          first_result = json_response[:results].first
          expect(first_result[:record_id]).to eq(1)
          expect(first_result[:charge_id]).to eq(charge1.id)
          expect(first_result[:charge_filter_id]).to eq(charge_filter.id)
          expect(first_result).to have_key(:charge_amount_cents_conservative)
          expect(first_result).to have_key(:charge_amount_cents_realistic)
          expect(first_result).to have_key(:charge_amount_cents_optimistic)

          second_result = json_response[:results].second
          expect(second_result[:record_id]).to eq(2)
          expect(second_result[:charge_id]).to eq(charge2.id)
          expect(second_result[:charge_filter_id]).to be_nil

          expect(Charges::CalculatePriceService).to have_received(:call).exactly(6).times
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 100, charge: charge1, charge_filter: charge_filter)
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 500, charge: charge1, charge_filter: charge_filter)
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 1000, charge: charge1, charge_filter: charge_filter)
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 200, charge: charge2, charge_filter: nil)
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 600, charge: charge2, charge_filter: nil)
          expect(Charges::CalculatePriceService).to have_received(:call).with(units: 1200, charge: charge2, charge_filter: nil)
        end
      end

      context "when no charges are provided" do
        let(:params) { {charges: []} }

        it "returns a bad request error" do
          subject

          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq("No charges provided")
        end
      end

      context "when charge is not found" do
        let(:params) do
          {
            charges: [
              {
                record_id: 3,
                charge_id: "nonexistent",
                units_conservative: 100
              }
            ]
          }
        end

        it "returns results with failed charges" do
          subject

          expect(response).to have_http_status(:success)

          json_response = json
          expect(json_response[:results]).to be_empty
          expect(json_response[:failed_charges].size).to eq(1)
          expect(json_response[:failed_charges].first[:record_id]).to eq(3)
          expect(json_response[:failed_charges].first[:charge_id]).to eq("nonexistent")
          expect(json_response[:failed_charges].first[:error]).to include("Charge not found")
          expect(json_response[:processed_count]).to eq(0)
          expect(json_response[:failed_count]).to eq(1)
        end
      end

      context "when charge_filter is not found" do
        let(:params) do
          {
            charges: [
              {
                record_id: 4,
                charge_id: charge1.id,
                charge_filter_id: "nonexistent",
                units_conservative: 100
              }
            ]
          }
        end

        it "returns results with failed charges" do
          subject

          expect(response).to have_http_status(:success)

          json_response = json
          expect(json_response[:results]).to be_empty
          expect(json_response[:failed_charges].size).to eq(1)
          expect(json_response[:failed_charges].first[:record_id]).to eq(4)
          expect(json_response[:failed_charges].first[:charge_id]).to eq(charge1.id)
          expect(json_response[:failed_charges].first[:error]).to include("ChargeFilter not found")
          expect(json_response[:processed_count]).to eq(0)
          expect(json_response[:failed_count]).to eq(1)
        end
      end

      context "when charges param is missing" do
        let(:params) { {} }

        it "returns a bad request error" do
          subject

          expect(response).to have_http_status(:bad_request)
          expect(json[:error]).to eq("No charges provided")
        end
      end

      context "with mixed successful and failed charges" do
        let(:params) do
          {
            charges: [
              {
                record_id: 5,
                charge_id: charge1.id,
                units_conservative: 100
              },
              {
                record_id: 6,
                charge_id: "nonexistent",
                units_conservative: 200
              }
            ]
          }
        end

        it "returns partial results" do
          subject

          expect(response).to have_http_status(:success)

          json_response = json
          expect(json_response[:results].size).to eq(1)
          expect(json_response[:failed_charges].size).to eq(1)
          expect(json_response[:processed_count]).to eq(1)
          expect(json_response[:failed_count]).to eq(1)
        end
      end
    end

    context "when authenticated but not premium" do
      it "returns forbidden status" do
        subject
        expect(response).to have_http_status(:forbidden)
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "when not authenticated" do
      def post_with_data_api_key(path, params = {})
        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
        post(path, params: params.to_json, headers:)
      end

      it "returns unauthorized status" do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
