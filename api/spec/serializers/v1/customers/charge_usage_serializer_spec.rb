# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Customers::ChargeUsageSerializer do
  subject(:serializer) { described_class.new(usage, root_name: "charges") }

  let(:charge) { create(:standard_charge) }
  let(:result) { JSON.parse(serializer.to_json) }
  let(:billable_metric) { charge.billable_metric }
  let(:subscription) { create(:subscription, plan: charge.plan) }
  let(:pricing_unit_usage) { nil }
  let(:presentation_breakdowns) { [] }

  let(:usage) do
    [build(:charge_fee,
      charge:,
      subscription:,
      units: "10",
      total_aggregated_units: "10",
      events_count: 12,
      amount_cents: 100,
      amount_currency: "EUR",
      grouped_by: {"card_type" => "visa"},
      charge_filter: nil,
      pricing_unit_usage:,
      presentation_breakdowns:)]
  end

  it "serializes the fee" do
    expect(result["charges"].first).to include(
      "units" => "10.0",
      "events_count" => 12,
      "amount_cents" => 100,
      "pricing_unit_details" => nil,
      "amount_currency" => "EUR",
      "charge" => {
        "lago_id" => charge.id,
        "code" => charge.code,
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
      "grouped_usage" => [
        {
          "amount_cents" => 100,
          "pricing_unit_details" => nil,
          "events_count" => 12,
          "units" => "10.0",
          "total_aggregated_units" => "10.0",
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
        build(:presentation_breakdown, presentation_by: {"card_type" => "visa"}, units: "8"),
        build(:presentation_breakdown, presentation_by: {"card_type" => "mastercard"}, units: "1"),
        build(:presentation_breakdown, presentation_by: {"country" => "pt"}, units: "3")
      ]
    end

    it "serializes the breakdowns" do
      expect(result["charges"].first["presentation_breakdowns"]).to eq([])
      expect(result["charges"].first["grouped_usage"].first["presentation_breakdowns"]).to match_array(
        [
          {"presentation_by" => {"card_type" => "visa"}, "units" => "8.0"},
          {"presentation_by" => {"card_type" => "mastercard"}, "units" => "1.0"},
          {"presentation_by" => {"country" => "pt"}, "units" => "3.0"}
        ]
      )
    end
  end

  context "when usage contains two objects, one with grouped_by and other without grouped_by" do
    let(:other_charge) { create(:standard_charge, plan: charge.plan) }
    let(:empty_group_presentation_breakdowns) { [] }
    let(:visa_group_presentation_breakdowns) { [] }

    let(:usage) do
      [
        build(:charge_fee,
          charge:,
          subscription:,
          units: "2",
          total_aggregated_units: "2",
          events_count: 2,
          amount_cents: 20,
          amount_currency: "EUR",
          grouped_by: {},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns: empty_group_presentation_breakdowns),
        build(:charge_fee,
          charge: other_charge,
          subscription:,
          units: "8",
          total_aggregated_units: "8",
          events_count: 10,
          amount_cents: 80,
          amount_currency: "EUR",
          grouped_by: {"card_type" => "visa"},
          charge_filter: nil,
          pricing_unit_usage:,
          presentation_breakdowns: visa_group_presentation_breakdowns)
      ]
    end

    it "serializes grouped usage including empty group" do
      expect(result["charges"].length).to eq(2)

      empty_group_charge = result["charges"].find { |c| c.dig("charge", "lago_id") == charge.id }
      visa_group_charge = result["charges"].find { |c| c.dig("charge", "lago_id") == other_charge.id }

      expect(empty_group_charge).to include(
        "units" => "2.0",
        "total_aggregated_units" => "2.0",
        "events_count" => 2,
        "amount_cents" => 20,
        "grouped_usage" => [],
        "presentation_breakdowns" => []
      )

      expect(visa_group_charge).to include(
        "units" => "8.0",
        "total_aggregated_units" => "8.0",
        "events_count" => 10,
        "amount_cents" => 80,
        "grouped_usage" => [
          {
            "amount_cents" => 80,
            "pricing_unit_details" => nil,
            "events_count" => 10,
            "units" => "8.0",
            "total_aggregated_units" => "8.0",
            "grouped_by" => {"card_type" => "visa"},
            "filters" => [],
            "presentation_breakdowns" => []
          }
        ]
      )
    end

    context "when contains presentation breakdowns" do
      let(:empty_group_presentation_breakdowns) do
        [
          build(:presentation_breakdown, presentation_by: {"card_type" => "visa"}, units: "8"),
          build(:presentation_breakdown, presentation_by: {"country" => "pt"}, units: "3")
        ]
      end
      let(:visa_group_presentation_breakdowns) do
        [
          build(:presentation_breakdown, presentation_by: {"card_type" => "mastercard"}, units: "1")
        ]
      end

      it "serializes breakdowns for ungrouped and grouped usage" do
        empty_group_charge = result["charges"].find { |c| c.dig("charge", "lago_id") == charge.id }
        visa_group_charge = result["charges"].find { |c| c.dig("charge", "lago_id") == other_charge.id }

        expect(empty_group_charge["grouped_usage"]).to eq([])
        expect(empty_group_charge["presentation_breakdowns"]).to match_array(
          [
            {"presentation_by" => {"card_type" => "visa"}, "units" => "8.0"},
            {"presentation_by" => {"country" => "pt"}, "units" => "3.0"}
          ]
        )

        expect(visa_group_charge["presentation_breakdowns"]).to eq([])
        expect(visa_group_charge["grouped_usage"].first["presentation_breakdowns"]).to match_array(
          [
            {"presentation_by" => {"card_type" => "mastercard"}, "units" => "1.0"}
          ]
        )
      end
    end
  end

  context "when charge configured to use pricing units" do
    let(:pricing_unit_usage) do
      PricingUnitUsage.new(amount_cents: 200, conversion_rate: 0.5, short_name: "CR")
    end

    it "serializes the fee" do
      expect(result["charges"].first).to include(
        "units" => "10.0",
        "total_aggregated_units" => "10.0",
        "events_count" => 12,
        "amount_cents" => 100,
        "pricing_unit_details" => {
          "amount_cents" => 200,
          "short_name" => "CR",
          "conversion_rate" => "0.5"
        },
        "amount_currency" => "EUR",
        "charge" => {
          "lago_id" => charge.id,
          "code" => charge.code,
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
        "grouped_usage" => [
          {
            "amount_cents" => 100,
            "pricing_unit_details" => {
              "amount_cents" => 200,
              "short_name" => "CR",
              "conversion_rate" => "0.5"
            },
            "events_count" => 12,
            "units" => "10.0",
            "total_aggregated_units" => "10.0",
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
        total_aggregated_units: "10.0",
        events_count: 12,
        amount_cents: 100,
        amount_currency: "EUR",
        grouped_by: {"card_type" => "visa"},
        charge_filter:,
        pricing_unit_usage:,
        presentation_breakdowns:)
    end

    it "returns filters array with projected values" do
      expect(result["charges"].first["filters"].first).to include(
        "units" => "30.0",
        "amount_cents" => 300,
        "events_count" => 36,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )

      expect(result["charges"].first["grouped_usage"].first["filters"].first).to include(
        "units" => "30.0",
        "amount_cents" => 300,
        "events_count" => 36,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )
    end

    context "when contains presentation breakdowns" do
      let(:presentation_breakdowns) do
        [build(:presentation_breakdown, presentation_by: {"cloud" => "aws"}, units: 4)]
      end

      it "serializes presentation_breakdowns in the filter" do
        filter_data = result["charges"].first["filters"].first
        expect(filter_data["presentation_breakdowns"]).to eq([
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

      it "returns filters array" do
        expect(result["charges"].first["filters"].first).to include(
          "units" => "30.0",
          "amount_cents" => 300,
          "pricing_unit_details" => {
            "amount_cents" => 600,
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
          "pricing_unit_details" => {
            "amount_cents" => 600,
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
end
