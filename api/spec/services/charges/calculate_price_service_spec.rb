# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::CalculatePriceService do
  subject(:calculate_price_service) { described_class.new(units:, charge:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:, amount_cents: 1000) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:units) { 5 }

  describe "#call" do
    context "when there is no charge for the billable metric" do
      let(:charge) { nil }

      it "fails with a validation error" do
        result = calculate_price_service.call

        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("charge_not_found")
      end
    end

    context "when there is a standard charge" do
      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          properties: {amount: "10"}
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        expect(result.charge_amount_cents).to eq(50) # 5 units * 10
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1050)
      end
    end

    context "when charge has pricing_group_keys but no grouped data" do
      let(:charge) do
        create(
          :standard_charge,
          plan:,
          billable_metric:,
          properties: {
            pricing_group_keys: ["region"],
            amount: "10"
          }
        )
      end

      it "calculates using base pricing without grouped service" do
        result = calculate_price_service.call

        expect(result.charge_amount_cents).to eq(50)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1050)
      end
    end

    context "when there is a graduated charge" do
      let(:charge) do
        create(
          :graduated_charge,
          plan:,
          billable_metric:,
          properties: {
            graduated_ranges: [
              {from_value: 0, to_value: 2, per_unit_amount: "2", flat_amount: "0"},
              {from_value: 3, to_value: nil, per_unit_amount: "3", flat_amount: "0"}
            ]
          }
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        # First range: 2 units * 2 = 4
        # Second range: 3 units * 3 = 9
        # Total charge: 13
        expect(result.charge_amount_cents).to eq(13)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1013)
      end
    end

    context "when there is a package charge" do
      let(:charge) do
        create(
          :package_charge,
          plan:,
          billable_metric:,
          properties: {
            package_size: 2,
            amount: "10",
            free_units: 1
          }
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        # 5 units - 1 free unit = 4 paid units
        # 4 paid units / 2 package size = 2 packages
        # 2 packages * 10 = 20
        expect(result.charge_amount_cents).to eq(20)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1020)
      end
    end

    context "when there is a volume charge" do
      let(:charge) do
        create(:volume_charge,
          plan:,
          billable_metric:,
          properties: {
            volume_ranges: [
              {from_value: 0, to_value: 2, per_unit_amount: "2", flat_amount: "0"},
              {from_value: 3, to_value: nil, per_unit_amount: "3", flat_amount: "0"}
            ]
          })
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        # All 5 units fall into the second range
        # 5 units * 3 = 15
        expect(result.charge_amount_cents).to eq(15)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1015)
      end
    end

    context "when there is a percentage charge" do
      let(:charge) do
        create(
          :percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            rate: "10"
          }
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        expect(result.charge_amount_cents).to eq(0.5)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1000.5)
      end
    end

    context "when there is a graduated percentage charge", :premium do
      let(:charge) do
        create(
          :graduated_percentage_charge,
          plan:,
          billable_metric:,
          properties: {
            graduated_percentage_ranges: [
              {from_value: 0, to_value: 2, rate: "10", flat_amount: "10"},
              {from_value: 3, to_value: nil, rate: "20", flat_amount: "20"}
            ]
          }
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        # First range: 2 units * 0.1 = 0.2
        # Second range: 3 units * 0.2 = 0.6
        # Total charge: 0.8
        expect(result.charge_amount_cents).to eq(30.8)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1030.8)
      end
    end

    context "when there is a dynamic charge", :premium do
      let(:billable_metric) { create(:sum_billable_metric, organization:) }

      let(:charge) do
        create(
          :dynamic_charge,
          plan:,
          billable_metric:
        )
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        expect(result.charge_amount_cents).to eq(0)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1000)
      end
    end

    context "when there is a custom charge", :premium do
      let(:billable_metric) { create(:custom_billable_metric, organization:) }

      let(:charge) do
        create(:custom_charge, plan:, billable_metric:)
      end

      it "calculates the total amount correctly" do
        result = calculate_price_service.call

        expect(result.charge_amount_cents).to eq(0)
        expect(result.subscription_amount_cents).to eq(1000)
        expect(result.total_amount_cents).to eq(1000)
      end
    end
  end
end
