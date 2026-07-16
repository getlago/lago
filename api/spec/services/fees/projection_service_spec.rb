# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fees::ProjectionService do
  subject(:service) { described_class.new(fees: fees) }

  let(:organization) { create(:organization) }

  let(:fees) { [fee] }
  let(:fee) do
    build(:fee,
      charge: charge,
      subscription: subscription,
      charge_filter: charge_filter,
      properties: fee_properties,
      amount_cents: 100,
      amount_currency: currency)
  end

  let(:billable_metric) do
    create(:billable_metric, recurring: false, organization:)
  end

  let(:charge) do
    create(:standard_charge,
      applied_pricing_unit: applied_pricing_unit,
      filters: [],
      billable_metric: billable_metric)
  end

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, plan:, organization:, customer:) }
  let(:plan) { create(:plan, amount_cents: 100, amount_currency: currency) }
  let(:currency) { "EUR" }

  let(:charge_filter) { nil }
  let(:applied_pricing_unit) { nil }

  let(:fee_properties) do
    {
      "from_datetime" => from_datetime,
      "to_datetime" => to_datetime,
      "charges_duration" => charges_duration
    }
  end

  let(:from_datetime) { Time.current.beginning_of_month }
  let(:to_datetime) { Time.current.end_of_month }
  let(:charges_duration) { nil }

  let(:aggregation_result) do
    instance_double(
      "AggregationResult",
      success?: true,
      error: nil
    )
  end

  let(:charge_model_result) do
    instance_double(
      "ChargeModelResult",
      success?: true,
      error: nil,
      projected_amount: BigDecimal("100.50"),
      projected_units: BigDecimal(10),
      unit_amount: BigDecimal("10.05")
    )
  end

  before do
    allow(BillableMetrics::AggregationFactory).to receive(:new_instance).and_return(
      instance_double("Aggregator", aggregate: aggregation_result)
    )

    allow(ChargeModels::Factory).to receive(:new_instance).and_return(
      instance_double("ChargeModel", apply: charge_model_result)
    )

    middle_time = from_datetime + ((to_datetime - from_datetime) / 2)
    travel_to(middle_time)
  end

  after do
    travel_back
  end

  describe "#call" do
    context "when aggregation fails" do
      let(:aggregation_result) do
        instance_double(
          "AggregationResult",
          success?: false,
          error: StandardError.new("Aggregation failed")
        )
      end

      it "returns failure with aggregation error" do
        result = service.call

        expect(result).to be_failure
        expect(result.error).to be_a(StandardError)
        expect(result.error.message).to eq("Aggregation failed")
      end
    end

    context "when charge model fails" do
      let(:charge_model_result) do
        instance_double(
          "ChargeModelResult",
          success?: false,
          error: StandardError.new("Charge model failed")
        )
      end

      it "returns failure with charge model error" do
        result = service.call

        expect(result).to be_failure
        expect(result.error).to be_a(StandardError)
        expect(result.error.message).to eq("Charge model failed")
      end
    end

    context "when everything succeeds" do
      it "returns projected values" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_amount_cents).to eq(10050) # 100.50 * 100
        expect(result.projected_units).to eq(BigDecimal(10))
        expect(result.projected_pricing_unit_amount_cents).to eq(nil) # No applied_pricing_unit
      end

      it "calls aggregation with correct parameters" do
        aggregator = instance_double("Aggregator", aggregate: aggregation_result)
        allow(BillableMetrics::AggregationFactory).to receive(:new_instance).and_return(aggregator)
        service.call
        expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
          charge: charge,
          subscription: subscription,
          boundaries: {
            from_datetime: match_datetime(from_datetime),
            to_datetime: match_datetime(to_datetime),
            charges_duration: charges_duration
          },
          filters: {charge_id: charge.id},
          current_usage: true
        )
        expect(aggregator).to have_received(:aggregate).with(options: {is_current_usage: true})
      end

      it "calls charge model factory with correct parameters" do
        from_date = from_datetime.to_date
        to_date = to_datetime.to_date
        current_date = Time.current.to_date

        total_days = (to_date - from_date).to_i + 1
        days_passed = (current_date - from_date).to_i + 1
        expected_period_ratio = days_passed.fdiv(total_days)

        service.call

        expect(ChargeModels::Factory).to have_received(:new_instance).with(
          chargeable: charge,
          aggregation_result:,
          properties: charge.properties,
          period_ratio: expected_period_ratio,
          calculate_projected_usage: true
        )
      end

      context "with presentation_breakdowns" do
        let(:from_datetime) { Time.zone.parse("2025-01-01T00:00:00") }
        let(:to_datetime) { Time.zone.parse("2025-01-10T23:59:59") }

        before do
          travel_to(from_datetime + 4.days)
          fee.presentation_breakdowns.build(
            organization: organization,
            presentation_by: {"department" => "engineering"},
            units: 60.33642
          )
        end

        it "returns projected_presentation_breakdowns as current units plus period_ratio applied to units" do
          result = service.call

          expect(result).to be_success
          expect(result.projected_presentation_breakdowns).to match_array([
            have_attributes(presentation_by: {"department" => "engineering"}, units: 120.67)
          ])
        end
      end
    end

    context "with charge filter" do
      let(:charge_filter) do
        create(:charge_filter, properties: {"amount" => "1000"})
      end

      let(:filter_service_result) do
        instance_double(
          "FilterServiceResult",
          matching_filters: ["filter1"],
          ignored_filters: ["filter2"]
        )
      end

      before do
        allow(ChargeFilters::MatchingAndIgnoredService).to receive(:call)
          .and_return(filter_service_result)
      end

      it "uses charge filter properties and filters" do
        allow(service).to receive(:period_ratio).and_return(0.5) # rubocop:disable RSpec/SubjectStub
        aggregator = instance_double("Aggregator", aggregate: aggregation_result)
        allow(BillableMetrics::AggregationFactory).to receive(:new_instance).and_return(aggregator)
        service.call
        expect(BillableMetrics::AggregationFactory).to have_received(:new_instance).with(
          charge: charge,
          subscription: subscription,
          boundaries: {
            from_datetime: match_datetime(from_datetime),
            to_datetime: match_datetime(to_datetime),
            charges_duration: charges_duration
          },
          filters: {
            charge_id: charge.id,
            charge_filter: charge_filter,
            matching_filters: ["filter1"],
            ignored_filters: ["filter2"]
          },
          current_usage: true
        )

        expect(ChargeModels::Factory).to have_received(:new_instance).with(
          chargeable: charge,
          aggregation_result:,
          properties: charge_filter.properties,
          period_ratio: 0.5,
          calculate_projected_usage: true
        )

        service.call
      end
    end

    context "with applied pricing unit" do
      let(:applied_pricing_unit) { build(:applied_pricing_unit) }
      let(:pricing_unit_usage) do
        instance_double(
          "PricingUnitUsage",
          to_fiat_currency_cents: {amount_cents: 5000}
        )
      end

      before do
        allow(PricingUnitUsage).to receive(:build_from_fiat_amounts)
          .and_return(pricing_unit_usage)
      end

      it "calculates projected pricing unit amount cents" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_pricing_unit_amount_cents).to eq(5000)

        expect(PricingUnitUsage).to have_received(:build_from_fiat_amounts).with(
          amount: BigDecimal("100.50"),
          unit_amount: BigDecimal("10.05"),
          applied_pricing_unit: applied_pricing_unit
        )
      end
    end

    context "when billable metric is recurring" do
      let(:billable_metric) { create(:billable_metric, recurring: true, aggregation_type: "sum_agg", field_name: "amount", organization:) }

      it "returns projected values without applying period_ratio" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_amount_cents).to eq(100)
        expect(result.projected_presentation_breakdowns).to eq([])
      end

      context "with presentation_breakdowns" do
        before do
          fee.presentation_breakdowns.build(
            organization: organization,
            presentation_by: {"department" => "engineering"},
            units: 60.0
          )
        end

        it "returns presentation_breakdowns with units unchanged" do
          result = service.call

          expect(result).to be_success
          expect(result.projected_presentation_breakdowns).to match_array([
            have_attributes(presentation_by: {"department" => "engineering"}, units: 60.0)
          ])
        end
      end
    end

    context "when period_ratio is out of range" do
      before { travel_to(from_datetime - 1.day) }

      it "returns empty projected_presentation_breakdowns" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_presentation_breakdowns).to eq([])
      end
    end
  end

  describe "period_ratio calculation" do
    let(:from_datetime) { Time.zone.parse("2025-01-01T00:00:00") }
    let(:to_datetime) { Time.zone.parse("2025-01-31T23:59:59") }

    context "when current date is in the middle of period" do
      before { travel_to(from_datetime + 10.days) }

      it "calculates correct ratio" do
        service.call

        expect(ChargeModels::Factory).to have_received(:new_instance).with(
          hash_including(period_ratio: 11.fdiv(31)) # January has 31 days
        )
      end
    end

    context "when customer is in a different timezone" do
      let(:customer) { create(:customer, organization:, timezone: "America/New_York") }
      let(:from_datetime) { Time.zone.parse("2025-01-01T05:00:00") }
      let(:to_datetime) { Time.zone.parse("2025-02-01T04:59:59") }

      before { travel_to(from_datetime + 10.days) }

      it "calculates correct ratio" do
        service.call

        expect(ChargeModels::Factory).to have_received(:new_instance).with(
          hash_including(period_ratio: 11.fdiv(31))
        )
      end
    end
  end

  describe "edge cases" do
    context "when projected_amount is nil" do
      let(:charge_model_result) do
        instance_double(
          "ChargeModelResult",
          success?: true,
          error: nil,
          projected_amount: nil,
          projected_units: BigDecimal(10),
          unit_amount: nil
        )
      end

      it "returns 0 for amount cents" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_amount_cents).to eq(0)
        expect(result.projected_pricing_unit_amount_cents).to eq(nil)
      end
    end

    context "when currency has different exponent" do
      let(:currency) { "KWD" }

      it "rounds and converts correctly" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_amount_cents).to eq(100500) # 100.50 * 1000
      end
    end

    context "when on the last day of the period" do
      let(:from_datetime) { Time.current.beginning_of_month }
      let(:to_datetime) { Time.current.end_of_month }

      before { travel_to(to_datetime - 5.hours) }

      it "returns projected values" do
        result = service.call

        expect(result).to be_success
        expect(result.projected_amount_cents).to eq(10050) # 100.50 * 100
        expect(result.projected_units).to eq(BigDecimal(10))
        expect(result.projected_pricing_unit_amount_cents).to eq(nil) # No applied_pricing_unit
      end
    end
  end
end
