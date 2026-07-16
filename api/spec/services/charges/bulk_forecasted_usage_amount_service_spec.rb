# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::BulkForecastedUsageAmountService do
  subject(:service) { described_class.new(charges_data: charges_data) }

  let(:organization) { create(:organization) }
  let(:billable_metric) { create(:billable_metric, organization: organization) }
  let(:plan) { create(:plan, organization: organization, amount_cents: 1000) }
  let(:charge1) do
    create(
      :standard_charge,
      plan: plan,
      billable_metric: billable_metric,
      properties: {amount: "10"}
    )
  end
  let(:charge2) do
    create(
      :standard_charge,
      plan: plan,
      billable_metric: billable_metric,
      properties: {amount: "20"}
    )
  end
  let(:charge_filter) { create(:charge_filter, charge: charge1) }

  let(:price_result) do
    BaseService::Result.new.tap do |result|
      result.charge_amount_cents = 10
      result.subscription_amount_cents = 10
      result.total_amount_cents = 20
    end
  end

  before do
    allow(Charges::CalculatePriceService).to receive(:call).and_return(price_result)
  end

  describe "#call" do
    context "when charges_data is empty" do
      let(:charges_data) { [] }

      it "returns empty results" do
        result = service.call

        expect(result).to be_success
        expect(result.results).to eq([])
        expect(result.failed_charges).to eq([])
        expect(result.processed_count).to eq(0)
        expect(result.failed_count).to eq(0)
      end
    end

    context "when processing valid charges with all percentile keys" do
      let(:charges_data) do
        [
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
      end

      it "returns successful results for all charges" do
        result = service.call

        expect(result).to be_success
        expect(result.results.size).to eq(2)
        expect(result.failed_charges).to be_empty
        expect(result.processed_count).to eq(2)
        expect(result.failed_count).to eq(0)
      end

      it "includes all percentile amounts in results" do
        result = service.call

        first_result = result.results.first
        expect(first_result[:record_id]).to eq(1)
        expect(first_result[:charge_id]).to eq(charge1.id)
        expect(first_result[:charge_filter_id]).to eq(charge_filter.id)
        expect(first_result[:charge_amount_cents_conservative]).to eq(1000)
        expect(first_result[:charge_amount_cents_realistic]).to eq(1000)
        expect(first_result[:charge_amount_cents_optimistic]).to eq(1000)
        expect(first_result[:subscription_amount_cents_conservative]).to eq(1000)
        expect(first_result[:subscription_amount_cents_realistic]).to eq(1000)
        expect(first_result[:subscription_amount_cents_optimistic]).to eq(1000)
        expect(first_result[:total_amount_cents_conservative]).to eq(2000)
        expect(first_result[:total_amount_cents_realistic]).to eq(2000)
        expect(first_result[:total_amount_cents_optimistic]).to eq(2000)

        second_result = result.results.second
        expect(second_result[:record_id]).to eq(2)
        expect(second_result[:charge_id]).to eq(charge2.id)
        expect(second_result[:charge_filter_id]).to be_nil
      end

      it "calls CalculatePriceService for each percentile" do
        service.call

        expect(Charges::CalculatePriceService).to have_received(:call).exactly(6).times
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 100,
          charge: charge1,
          charge_filter: charge_filter
        )
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 500,
          charge: charge1,
          charge_filter: charge_filter
        )
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 1000,
          charge: charge1,
          charge_filter: charge_filter
        )
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 200,
          charge: charge2,
          charge_filter: nil
        )
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 600,
          charge: charge2,
          charge_filter: nil
        )
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 1200,
          charge: charge2,
          charge_filter: nil
        )
      end

      it "multiplies amounts by 100" do
        result = service.call

        first_result = result.results.first
        expect(first_result[:charge_amount_cents_conservative]).to eq(
          price_result.charge_amount_cents * 100
        )
        expect(first_result[:subscription_amount_cents_conservative]).to eq(
          price_result.subscription_amount_cents * 100
        )
        expect(first_result[:total_amount_cents_conservative]).to eq(
          price_result.total_amount_cents * 100
        )
      end

      it "logs response summary" do
        allow(Rails.logger).to receive(:info)

        service.call

        expect(Rails.logger).to have_received(:info).with(
          /\[ChargesController\] Response summary:/
        )
      end
    end

    context "when processing charges with partial percentile keys" do
      let(:charges_data) do
        [
          {
            record_id: 3,
            charge_id: charge1.id,
            units_conservative: 100
          }
        ]
      end

      it "only includes amounts for provided percentile keys" do
        result = service.call

        expect(result).to be_success
        first_result = result.results.first
        expect(first_result).to have_key(:charge_amount_cents_conservative)
        expect(first_result).not_to have_key(:charge_amount_cents_realistic)
        expect(first_result).not_to have_key(:charge_amount_cents_optimistic)
      end

      it "calls CalculatePriceService only for provided percentiles" do
        service.call

        expect(Charges::CalculatePriceService).to have_received(:call).once
        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 100,
          charge: charge1,
          charge_filter: nil
        )
      end
    end

    context "when charge is not found" do
      let(:charges_data) do
        [
          {
            record_id: 4,
            charge_id: "nonexistent",
            units_conservative: 100
          }
        ]
      end

      it "adds charge to failed_charges" do
        result = service.call

        expect(result).to be_success
        expect(result.results).to be_empty
        expect(result.failed_charges.size).to eq(1)
        expect(result.failed_charges.first[:record_id]).to eq(4)
        expect(result.failed_charges.first[:charge_id]).to eq("nonexistent")
        expect(result.failed_charges.first[:error]).to include("Charge not found")
        expect(result.processed_count).to eq(0)
        expect(result.failed_count).to eq(1)
      end
    end

    context "when charge_filter is not found" do
      let(:charges_data) do
        [
          {
            record_id: 5,
            charge_id: charge1.id,
            charge_filter_id: "nonexistent",
            units_conservative: 100
          }
        ]
      end

      it "adds charge to failed_charges" do
        result = service.call

        expect(result).to be_success
        expect(result.results).to be_empty
        expect(result.failed_charges.size).to eq(1)
        expect(result.failed_charges.first[:record_id]).to eq(5)
        expect(result.failed_charges.first[:charge_id]).to eq(charge1.id)
        expect(result.failed_charges.first[:error]).to include("ChargeFilter not found")
        expect(result.processed_count).to eq(0)
        expect(result.failed_count).to eq(1)
      end
    end

    context "with mixed successful and failed charges" do
      let(:charges_data) do
        [
          {
            record_id: 6,
            charge_id: charge1.id,
            units_conservative: 100
          },
          {
            record_id: 7,
            charge_id: "nonexistent",
            units_conservative: 200
          },
          {
            record_id: 8,
            charge_id: charge2.id,
            units_realistic: 300
          }
        ]
      end

      it "returns partial results with both successful and failed charges" do
        result = service.call

        expect(result).to be_success
        expect(result.results.size).to eq(2)
        expect(result.failed_charges.size).to eq(1)
        expect(result.processed_count).to eq(2)
        expect(result.failed_count).to eq(1)

        expect(result.results.first[:record_id]).to eq(6)
        expect(result.results.second[:record_id]).to eq(8)
        expect(result.failed_charges.first[:record_id]).to eq(7)
      end
    end

    context "when processing charges without charge_filter_id" do
      let(:charges_data) do
        [
          {
            record_id: 10,
            charge_id: charge1.id,
            units_conservative: 100
          }
        ]
      end

      it "passes nil charge_filter to CalculatePriceService" do
        service.call

        expect(Charges::CalculatePriceService).to have_received(:call).with(
          units: 100,
          charge: charge1,
          charge_filter: nil
        )
      end

      it "includes nil charge_filter_id in results" do
        result = service.call

        first_result = result.results.first
        expect(first_result[:charge_filter_id]).to be_nil
      end
    end

    context "when bulk loading charges and charge_filters" do
      let(:charges_data) do
        [
          {record_id: 11, charge_id: charge1.id, units_conservative: 100},
          {record_id: 12, charge_id: charge2.id, units_conservative: 200},
          {record_id: 13, charge_id: charge1.id, units_conservative: 300}
        ]
      end

      it "loads charges only once" do
        allow(Charge).to receive(:where).and_call_original

        service.call

        expect(Charge).to have_received(:where).with(id: [charge1.id, charge2.id])
      end

      it "processes all charges successfully" do
        result = service.call

        expect(result).to be_success
        expect(result.results.size).to eq(3)
        expect(result.failed_charges).to be_empty
      end
    end
  end
end
