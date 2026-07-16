# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Customers::ProjectedChargeUsageSerializer do
  subject(:serializer) { described_class.new(usage, root_name: "charges") }

  let(:charge) { create(:standard_charge) }
  let(:result) { JSON.parse(serializer.to_json) }
  let(:billable_metric) { charge.billable_metric }
  let(:subscription) { create(:subscription, plan: charge.plan) }
  let(:from_datetime) { Date.new(2025, 7, 1) }
  let(:to_datetime) { Date.new(2025, 7, 10) } # 10 day period for clean ratios
  let(:fixed_date) { Date.new(2025, 7, 5) } # 5 days passed, ratio = 0.5

  let(:total_days) { (to_datetime - from_datetime).to_i + 1 }
  let(:charges_duration) { total_days }
  let(:days_passed) { (fixed_date - from_datetime).to_i + 1 }
  let(:ratio) { days_passed.to_f / charges_duration }

  let(:is_recurring) { false }
  let(:expected_projected_units) do
    if is_recurring
      BigDecimal(10)
    else
      (ratio > 0) ? (BigDecimal(10) / BigDecimal(ratio.to_s)).round(1) : BigDecimal(0)
    end
  end
  let(:expected_projected_amount_cents) do
    if is_recurring
      100
    else
      (ratio > 0) ? (BigDecimal(100) / BigDecimal(ratio.to_s)).round.to_i : 0
    end
  end
  let(:expected_pricing_unit_projected_amount_cents) do
    if is_recurring
      200
    else
      (ratio > 0) ? (BigDecimal(200) / BigDecimal(ratio.to_s)).round.to_i : 0
    end
  end
  let(:greater_expected_pricing_unit_projected_amount_cents) do
    if is_recurring
      600
    else
      (ratio > 0) ? (BigDecimal(600) / BigDecimal(ratio.to_s)).round.to_i : 0
    end
  end
  let(:pricing_unit_usage) { nil }
  let(:presentation_breakdowns) { [] }

  let(:usage) do
    [build(:charge_fee,
      charge:,
      subscription:,
      units: "10",
      events_count: 12,
      amount_cents: 100,
      amount_currency: "EUR",
      grouped_by: {"card_type" => "visa"},
      charge_filter: nil,
      pricing_unit_usage:,
      presentation_breakdowns:)]
  end

  let(:expected_projected_presentation_breakdowns) do
    [
      build(:presentation_breakdown, presentation_by: {"card_type" => "visa"}, units: 3.5),
      build(:presentation_breakdown, presentation_by: {"card_type" => "mastercard"}, units: 0.5),
      build(:presentation_breakdown, presentation_by: {"country" => "br"}, units: 1.5)
    ]
  end

  around { |example| travel_to(fixed_date) { example.run } }

  it "serializes the projected fee" do
    projection_result = instance_double(
      "ProjectionResult",
      projected_units: expected_projected_units,
      projected_amount_cents: expected_projected_amount_cents,
      projected_pricing_unit_amount_cents: expected_pricing_unit_projected_amount_cents,
      projected_presentation_breakdowns: expected_projected_presentation_breakdowns
    )

    allow(::Fees::ProjectionService).to receive(:call).and_return(
      instance_double("ServiceResult", raise_if_error!: projection_result)
    )

    expect(result["charges"].first).to include(
      "units" => "10.0",
      "projected_units" => expected_projected_units.to_s,
      "events_count" => 12,
      "amount_cents" => 100,
      "projected_amount_cents" => expected_projected_amount_cents,
      "pricing_unit_details" => nil,
      "amount_currency" => "EUR",
      "charge" => {
        "lago_id" => charge.id,
        "charge_model" => charge.charge_model,
        "invoice_display_name" => charge.invoice_display_name
      },
      "billable_metric" => {
        "lago_id" => billable_metric.id,
        "name" => billable_metric.name,
        "code" => billable_metric.code,
        "aggregation_type" => billable_metric.aggregation_type
      },
      "filters" => [],
      "presentation_breakdowns" => [],
      "projected_presentation_breakdowns" => [],
      "grouped_usage" => [
        {
          "amount_cents" => 100,
          "projected_amount_cents" => expected_projected_amount_cents,
          "projected_presentation_breakdowns" => [
            {"presentation_by" => {"card_type" => "visa"}, "units" => "3.5"},
            {"presentation_by" => {"card_type" => "mastercard"}, "units" => "0.5"},
            {"presentation_by" => {"country" => "br"}, "units" => "1.5"}
          ],
          "pricing_unit_details" => nil,
          "events_count" => 12,
          "units" => "10.0",
          "projected_units" => expected_projected_units.to_s,
          "grouped_by" => {"card_type" => "visa"},
          "filters" => [],
          "presentation_breakdowns" => []
        }
      ]
    )
  end

  context "when contains presentation breakdowns" do
    let(:presentation_breakdowns) do
      [
        build(:presentation_breakdown, presentation_by: {"card_type" => "visa"}, units: "7"),
        build(:presentation_breakdown, presentation_by: {"card_type" => "mastercard"}, units: "1"),
        build(:presentation_breakdown, presentation_by: {"country" => "br"}, units: "3")
      ]
    end

    it "serializes the breakdowns" do
      projection_result = instance_double(
        "ProjectionResult",
        projected_units: expected_projected_units,
        projected_amount_cents: expected_projected_amount_cents,
        projected_pricing_unit_amount_cents: expected_pricing_unit_projected_amount_cents,
        projected_presentation_breakdowns: expected_projected_presentation_breakdowns
      )

      allow(::Fees::ProjectionService).to receive(:call).and_return(
        instance_double("ServiceResult", raise_if_error!: projection_result)
      )

      expect(result["charges"].first["presentation_breakdowns"]).to eq([])
      expect(result["charges"].first["projected_presentation_breakdowns"]).to eq([])

      expect(result["charges"].first["grouped_usage"].first["presentation_breakdowns"]).to match_array(
        [
          {"presentation_by" => {"card_type" => "visa"}, "units" => "7.0"},
          {"presentation_by" => {"card_type" => "mastercard"}, "units" => "1.0"},
          {"presentation_by" => {"country" => "br"}, "units" => "3.0"}
        ]
      )

      expect(result["charges"].first["grouped_usage"].first["projected_presentation_breakdowns"]).to match_array(
        [
          {"presentation_by" => {"card_type" => "visa"}, "units" => "3.5"},
          {"presentation_by" => {"card_type" => "mastercard"}, "units" => "0.5"},
          {"presentation_by" => {"country" => "br"}, "units" => "1.5"}
        ]
      )
    end
  end

  context "when charge configured to use pricing units" do
    let(:pricing_unit_usage) do
      PricingUnitUsage.new(amount_cents: 200, conversion_rate: 0.5, short_name: "CR")
    end

    it "serializes the projected fee with pricing units" do
      projection_result = instance_double(
        "ProjectionResult",
        projected_units: expected_projected_units,
        projected_amount_cents: expected_projected_amount_cents,
        projected_pricing_unit_amount_cents: expected_pricing_unit_projected_amount_cents,
        projected_presentation_breakdowns: expected_projected_presentation_breakdowns
      )

      allow(::Fees::ProjectionService).to receive(:call).and_return(
        instance_double("ServiceResult", raise_if_error!: projection_result)
      )

      expect(result["charges"].first).to include(
        "units" => "10.0",
        "projected_units" => expected_projected_units.to_s,
        "events_count" => 12,
        "amount_cents" => 100,
        "projected_amount_cents" => expected_projected_amount_cents,
        "pricing_unit_details" => {
          "amount_cents" => 200,
          "projected_amount_cents" => expected_pricing_unit_projected_amount_cents,
          "short_name" => "CR",
          "conversion_rate" => "0.5"
        },
        "amount_currency" => "EUR",
        "charge" => {
          "lago_id" => charge.id,
          "charge_model" => charge.charge_model,
          "invoice_display_name" => charge.invoice_display_name
        },
        "billable_metric" => {
          "lago_id" => billable_metric.id,
          "name" => billable_metric.name,
          "code" => billable_metric.code,
          "aggregation_type" => billable_metric.aggregation_type
        },
        "filters" => [],
        "presentation_breakdowns" => [],
        "projected_presentation_breakdowns" => [],
        "grouped_usage" => [
          {
            "amount_cents" => 100,
            "projected_amount_cents" => expected_projected_amount_cents,
            "projected_presentation_breakdowns" => [
              {"presentation_by" => {"card_type" => "visa"}, "units" => "3.5"},
              {"presentation_by" => {"card_type" => "mastercard"}, "units" => "0.5"},
              {"presentation_by" => {"country" => "br"}, "units" => "1.5"}
            ],
            "pricing_unit_details" => {
              "amount_cents" => 200,
              "projected_amount_cents" => expected_pricing_unit_projected_amount_cents,
              "short_name" => "CR",
              "conversion_rate" => "0.5"
            },
            "events_count" => 12,
            "units" => "10.0",
            "projected_units" => expected_projected_units.to_s,
            "grouped_by" => {"card_type" => "visa"},
            "filters" => [],
            "presentation_breakdowns" => []
          }
        ]
      )
    end
  end

  describe "#filters" do
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric: billable_metric) }
    let(:charge_filter) { create(:charge_filter, charge: charge, invoice_display_name: nil) }
    let(:usage) do
      build_list(:charge_fee, 3,
        charge:,
        subscription:,
        units: "10.0",
        events_count: 12,
        amount_cents: 100,
        amount_currency: "EUR",
        grouped_by: {"card_type" => "visa"},
        charge_filter:,
        pricing_unit_usage:,
        presentation_breakdowns:)
    end

    let(:expected_filter_projected_units) do
      if is_recurring
        BigDecimal(30)
      else
        (ratio > 0) ? (BigDecimal(30) / BigDecimal(ratio.to_s)).round(2) : BigDecimal(0)
      end
    end
    let(:expected_filter_projected_amount_cents) do
      if is_recurring
        300
      else
        (ratio > 0) ? (300 / BigDecimal(ratio.to_s)).round.to_i : 0
      end
    end

    it "returns projected filters array" do
      individual_projection_result = instance_double(
        "ProjectionResult",
        projected_units: expected_filter_projected_units / 3,
        projected_amount_cents: expected_filter_projected_amount_cents / 3,
        projected_pricing_unit_amount_cents: greater_expected_pricing_unit_projected_amount_cents / 3,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call).and_return(
        instance_double("ServiceResult", raise_if_error!: individual_projection_result)
      )

      expect(result["charges"].first["filters"].first).to include(
        "units" => "30.0",
        "projected_units" => expected_filter_projected_units.to_s,
        "amount_cents" => 300,
        "projected_amount_cents" => expected_filter_projected_amount_cents,
        "events_count" => 36,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )

      expect(result["charges"].first["grouped_usage"].first["filters"].first).to include(
        "units" => "30.0",
        "projected_units" => expected_filter_projected_units.to_s,
        "amount_cents" => 300,
        "projected_amount_cents" => expected_filter_projected_amount_cents,
        "events_count" => 36,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )
    end

    context "when contains presentation breakdowns" do
      let(:presentation_breakdowns) do
        [build(:presentation_breakdown, presentation_by: {"cloud" => "aws"}, units: 4)]
      end

      before do
        individual_projection_result = instance_double(
          "ProjectionResult",
          projected_units: expected_filter_projected_units / 3,
          projected_amount_cents: expected_filter_projected_amount_cents / 3,
          projected_pricing_unit_amount_cents: greater_expected_pricing_unit_projected_amount_cents / 3,
          projected_presentation_breakdowns: presentation_breakdowns
        )
        allow(::Fees::ProjectionService).to receive(:call).and_return(
          instance_double("ServiceResult", raise_if_error!: individual_projection_result)
        )
      end

      it "serializes presentation_breakdowns in the filter" do
        filter_data = result["charges"].first["filters"].first
        expect(filter_data["presentation_breakdowns"]).to eq([
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"},
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"},
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"}
        ])
        expect(filter_data["projected_presentation_breakdowns"]).to eq([
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"},
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"},
          {"presentation_by" => {"cloud" => "aws"}, "units" => "4.0"}
        ])
      end
    end

    context "when charge configured to use pricing units" do
      let(:pricing_unit_usage) do
        PricingUnitUsage.new(amount_cents: 200, conversion_rate: 0.5, short_name: "CR")
      end

      it "returns projected filters array with pricing units" do
        individual_projection_result = instance_double(
          "ProjectionResult",
          projected_units: expected_filter_projected_units / 3,
          projected_amount_cents: expected_filter_projected_amount_cents / 3,
          projected_pricing_unit_amount_cents: greater_expected_pricing_unit_projected_amount_cents / 3,
          projected_presentation_breakdowns: []
        )

        allow(::Fees::ProjectionService).to receive(:call).and_return(
          instance_double("ServiceResult", raise_if_error!: individual_projection_result)
        )

        expect(result["charges"].first["filters"].first).to include(
          "units" => "30.0",
          "amount_cents" => 300,
          "projected_units" => expected_filter_projected_units.to_s,
          "projected_amount_cents" => expected_filter_projected_amount_cents,
          "pricing_unit_details" => {
            "amount_cents" => 600,
            "projected_amount_cents" => greater_expected_pricing_unit_projected_amount_cents,
            "short_name" => "CR",
            "conversion_rate" => "0.5"
          },
          "events_count" => 36,
          "invoice_display_name" => charge_filter.invoice_display_name,
          "values" => {}
        )

        expect(result["charges"].first["grouped_usage"].first["filters"].first).to include(
          "units" => "30.0",
          "amount_cents" => 300,
          "projected_units" => expected_filter_projected_units.to_s,
          "projected_amount_cents" => expected_filter_projected_amount_cents,
          "pricing_unit_details" => {
            "amount_cents" => 600,
            "projected_amount_cents" => greater_expected_pricing_unit_projected_amount_cents,
            "short_name" => "CR",
            "conversion_rate" => "0.5"
          },
          "events_count" => 36,
          "invoice_display_name" => charge_filter.invoice_display_name,
          "values" => {}
        )
      end
    end
  end

  describe "multiple charge filters" do
    let(:charge_filter_1) { create(:charge_filter, charge: charge, invoice_display_name: "Filter 1") }
    let(:charge_filter_2) { create(:charge_filter, charge: charge, invoice_display_name: "Filter 2") }
    let(:usage) do
      [
        build(:charge_fee,
          charge:,
          subscription:,
          units: "5.0",
          events_count: 8,
          amount_cents: 50,
          amount_currency: "EUR",
          grouped_by: {},
          charge_filter: charge_filter_1,
          pricing_unit_usage:,
          presentation_breakdowns:),
        build(:charge_fee,
          charge:,
          subscription:,
          units: "7.0",
          events_count: 10,
          amount_cents: 70,
          amount_currency: "EUR",
          grouped_by: {},
          charge_filter: charge_filter_2,
          pricing_unit_usage:,
          presentation_breakdowns:)
      ]
    end

    it "handles multiple filters with different projection calculations" do
      projection_result_1 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(10),
        projected_amount_cents: 100,
        projected_pricing_unit_amount_cents: 150,
        projected_presentation_breakdowns: []
      )

      projection_result_2 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(14),
        projected_amount_cents: 140,
        projected_pricing_unit_amount_cents: 210,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[0]]).and_return(projection_result_1)
      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[1]]).and_return(projection_result_2)

      filters = result["charges"].first["filters"]

      expect(filters.size).to eq(2)

      expect(filters[0]).to include(
        "units" => "5.0",
        "projected_units" => "10.0",
        "amount_cents" => 50,
        "projected_amount_cents" => 100,
        "events_count" => 8,
        "invoice_display_name" => "Filter 1",
        "values" => {}
      )

      expect(filters[1]).to include(
        "units" => "7.0",
        "projected_units" => "14.0",
        "amount_cents" => 70,
        "projected_amount_cents" => 140,
        "events_count" => 10,
        "invoice_display_name" => "Filter 2",
        "values" => {}
      )
    end
  end

  describe "multiple grouped usage scenarios" do
    let(:usage) do
      [
        build(:charge_fee,
          charge:,
          subscription:,
          units: "3.0",
          events_count: 5,
          amount_cents: 30,
          amount_currency: "EUR",
          grouped_by: {"region" => "us-east", "tier" => "premium"},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns:),
        build(:charge_fee,
          charge:,
          subscription:,
          units: "4.0",
          events_count: 7,
          amount_cents: 40,
          amount_currency: "EUR",
          grouped_by: {"region" => "us-west", "tier" => "standard"},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns:),
        build(:charge_fee,
          charge:,
          subscription:,
          units: "5.0",
          events_count: 8,
          amount_cents: 50,
          amount_currency: "EUR",
          grouped_by: {"region" => "eu-central", "tier" => "premium"},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns:)
      ]
    end

    it "handles multiple groups with independent projection calculations" do
      projection_result_1 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(6),
        projected_amount_cents: 60,
        projected_pricing_unit_amount_cents: 90,
        projected_presentation_breakdowns: []
      )

      projection_result_2 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(8),
        projected_amount_cents: 80,
        projected_pricing_unit_amount_cents: 120,
        projected_presentation_breakdowns: []
      )

      projection_result_3 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(10),
        projected_amount_cents: 100,
        projected_pricing_unit_amount_cents: 150,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[0]]).and_return(projection_result_1)
      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[1]]).and_return(projection_result_2)
      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[2]]).and_return(projection_result_3)

      grouped_usage = result["charges"].first["grouped_usage"]

      expect(grouped_usage.size).to eq(3)

      expect(grouped_usage[0]).to include(
        "units" => "3.0",
        "projected_units" => "6.0",
        "amount_cents" => 30,
        "projected_amount_cents" => 60,
        "events_count" => 5,
        "grouped_by" => {"region" => "us-east", "tier" => "premium"}
      )

      expect(grouped_usage[1]).to include(
        "units" => "4.0",
        "projected_units" => "8.0",
        "amount_cents" => 40,
        "projected_amount_cents" => 80,
        "events_count" => 7,
        "grouped_by" => {"region" => "us-west", "tier" => "standard"}
      )

      expect(grouped_usage[2]).to include(
        "units" => "5.0",
        "projected_units" => "10.0",
        "amount_cents" => 50,
        "projected_amount_cents" => 100,
        "events_count" => 8,
        "grouped_by" => {"region" => "eu-central", "tier" => "premium"}
      )
    end
  end

  describe "mixed filtering and grouping" do
    let(:charge_filter) { create(:charge_filter, charge: charge, invoice_display_name: "Mixed Filter") }
    let(:usage) do
      [
        build(:charge_fee,
          charge:,
          subscription:,
          units: "2.0",
          events_count: 3,
          amount_cents: 20,
          amount_currency: "EUR",
          grouped_by: {"datacenter" => "dc1"},
          charge_filter:,
          pricing_unit_usage:,
          presentation_breakdowns:),
        build(:charge_fee,
          charge:,
          subscription:,
          units: "3.0",
          events_count: 4,
          amount_cents: 30,
          amount_currency: "EUR",
          grouped_by: {"datacenter" => "dc2"},
          charge_filter:,
          pricing_unit_usage:,
          presentation_breakdowns:)
      ]
    end

    it "correctly handles fees with both filters and grouping" do
      projection_result_1 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(4),
        projected_amount_cents: 40,
        projected_pricing_unit_amount_cents: 60,
        projected_presentation_breakdowns: []
      )

      projection_result_2 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(6),
        projected_amount_cents: 60,
        projected_pricing_unit_amount_cents: 90,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[0]]).and_return(projection_result_1)
      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[1]]).and_return(projection_result_2)

      charge_result = result["charges"].first

      expect(charge_result["filters"].size).to eq(1)
      expect(charge_result["filters"].first).to include(
        "units" => "5.0",
        "projected_units" => "10.0",
        "amount_cents" => 50,
        "projected_amount_cents" => 100,
        "events_count" => 7,
        "invoice_display_name" => "Mixed Filter",
        "values" => {}
      )

      expect(charge_result["grouped_usage"].size).to eq(2)
      expect(charge_result["grouped_usage"][0]).to include(
        "units" => "2.0",
        "projected_units" => "4.0",
        "amount_cents" => 20,
        "projected_amount_cents" => 40,
        "grouped_by" => {"datacenter" => "dc1"}
      )
      expect(charge_result["grouped_usage"][1]).to include(
        "units" => "3.0",
        "projected_units" => "6.0",
        "amount_cents" => 30,
        "projected_amount_cents" => 60,
        "grouped_by" => {"datacenter" => "dc2"}
      )
    end
  end

  describe "multiple charges with different calculations" do
    let(:charge_2) { create(:standard_charge) }
    let(:usage) do
      [
        build(:charge_fee,
          charge:,
          subscription:,
          units: "10.0",
          events_count: 15,
          amount_cents: 100,
          amount_currency: "EUR",
          grouped_by: {},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns:),
        build(:charge_fee,
          charge: charge_2,
          subscription:,
          units: "20.0",
          events_count: 25,
          amount_cents: 200,
          amount_currency: "EUR",
          grouped_by: {},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns:)
      ]
    end

    it "handles multiple charges with independent calculations" do
      projection_result_1 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(20),
        projected_amount_cents: 200,
        projected_pricing_unit_amount_cents: 300,
        projected_presentation_breakdowns: []
      )

      projection_result_2 = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(40),
        projected_amount_cents: 400,
        projected_pricing_unit_amount_cents: 600,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[0]]).and_return(projection_result_1)
      allow(::Fees::ProjectionService).to receive(:call!).with(fees: [usage[1]]).and_return(projection_result_2)

      charges = result["charges"]
      expect(charges.size).to eq(2)

      expect(charges[0]).to include(
        "units" => "10.0",
        "projected_units" => "20.0",
        "amount_cents" => 100,
        "projected_amount_cents" => 200,
        "events_count" => 15
      )
      expect(charges[0]["charge"]["lago_id"]).to eq(charge.id)

      expect(charges[1]).to include(
        "units" => "20.0",
        "projected_units" => "40.0",
        "amount_cents" => 200,
        "projected_amount_cents" => 400,
        "events_count" => 25
      )
      expect(charges[1]["charge"]["lago_id"]).to eq(charge_2.id)
    end
  end

  describe "memoization behavior" do
    let(:usage) do
      [build(:charge_fee,
        charge:,
        subscription:,
        units: "5.0",
        events_count: 8,
        amount_cents: 50,
        amount_currency: "EUR",
        grouped_by: {},
        charge_filter: nil,
        pricing_unit_usage:,
        presentation_breakdowns:)]
    end

    it "calls projection service only once per unique fee set" do
      projection_result = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(10),
        projected_amount_cents: 100,
        projected_pricing_unit_amount_cents: 150,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call!).with(fees: usage).and_return(projection_result)

      result

      charge_result = result["charges"].first
      expect(charge_result).to include(
        "projected_units" => "10.0",
        "projected_amount_cents" => 100
      )

      expect(::Fees::ProjectionService).to have_received(:call!).with(fees: usage).once
    end
  end

  describe "recurring charges" do
    let(:is_recurring) { true }

    before do
      allow(charge.billable_metric).to receive(:recurring?).and_return(true)
    end

    it "returns current values for recurring charges" do
      projection_result = instance_double(
        "ProjectionResult",
        projected_units: BigDecimal(10),
        projected_amount_cents: 100,
        projected_pricing_unit_amount_cents: 200,
        projected_presentation_breakdowns: []
      )

      allow(::Fees::ProjectionService).to receive(:call).and_return(
        instance_double("ServiceResult", raise_if_error!: projection_result)
      )

      expect(result["charges"].first).to include(
        "units" => "10.0",
        "projected_units" => "10.0",
        "projected_amount_cents" => 100
      )
    end
  end
end
