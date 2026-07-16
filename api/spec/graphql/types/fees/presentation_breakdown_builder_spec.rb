# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Fees::PresentationBreakdownBuilder do
  subject(:result) { described_class.call(fees, filter:, filter_breakdown:) }

  let(:filter) { described_class::UNGROUPED }
  let(:filter_breakdown) { described_class::ALL }
  let(:fees) { [fee_one, fee_two] }

  let(:fee_one) do
    build(
      :charge_fee,
      grouped_by: {},
      presentation_breakdowns: [
        build(:presentation_breakdown, presentation_by: {"cloud" => "aws"}, units: 1.2)
      ]
    )
  end

  let(:fee_two) do
    build(
      :charge_fee,
      invoice: fee_one.invoice,
      grouped_by: {},
      presentation_breakdowns: [
        build(:presentation_breakdown, presentation_by: {"cloud" => "aws"}, units: 0.3),
        build(:presentation_breakdown, presentation_by: {"cloud" => "gcp"}, units: 3)
      ]
    )
  end

  it "returns one entry per breakdown with stringified units" do
    expect(result).to eq([
      {presentation_by: {"cloud" => "aws"}, units: "1.2"},
      {presentation_by: {"cloud" => "aws"}, units: "0.3"},
      {presentation_by: {"cloud" => "gcp"}, units: "3.0"}
    ])
  end

  context "when fees contain no presentation_breakdowns" do
    let(:fees) { [build(:charge_fee, grouped_by: {}, presentation_breakdowns: [])] }

    it "returns an empty array" do
      expect(result).to eq([])
    end
  end

  describe "filter" do
    let(:ungrouped_fee) do
      build(
        :charge_fee,
        grouped_by: {},
        presentation_breakdowns: [
          build(:presentation_breakdown, presentation_by: {"region" => "us"}, units: 1)
        ]
      )
    end

    let(:grouped_fee) do
      build(
        :charge_fee,
        grouped_by: {"region" => "eu"},
        presentation_breakdowns: [
          build(:presentation_breakdown, presentation_by: {"region" => "eu"}, units: 2)
        ]
      )
    end

    let(:filtered_ungrouped_fee) do
      build(
        :charge_fee,
        grouped_by: {},
        charge_filter_id: SecureRandom.uuid,
        presentation_breakdowns: [
          build(:presentation_breakdown, presentation_by: {"region" => "us"}, units: 3)
        ]
      )
    end

    let(:filtered_grouped_fee) do
      build(
        :charge_fee,
        grouped_by: {"region" => "eu"},
        charge_filter_id: SecureRandom.uuid,
        presentation_breakdowns: [
          build(:presentation_breakdown, presentation_by: {"region" => "eu"}, units: 4)
        ]
      )
    end

    let(:fees) { [ungrouped_fee, grouped_fee, filtered_ungrouped_fee, filtered_grouped_fee] }

    context "when filter is UNGROUPED" do
      let(:filter) { described_class::UNGROUPED }

      it "includes only fees with blank grouped_by and no charge_filter_id" do
        expect(result).to eq([
          {presentation_by: {"region" => "us"}, units: "1.0"}
        ])
      end
    end

    context "when filter is GROUPED" do
      let(:filter) { described_class::GROUPED }

      it "includes only fees with present grouped_by and no charge_filter_id" do
        expect(result).to eq([
          {presentation_by: {"region" => "eu"}, units: "2.0"}
        ])
      end
    end

    context "when filter is ALL" do
      let(:filter) { described_class::ALL }

      it "includes breakdowns from all fees regardless of grouped_by or charge_filter_id" do
        expect(result).to eq([
          {presentation_by: {"region" => "us"}, units: "1.0"},
          {presentation_by: {"region" => "eu"}, units: "2.0"},
          {presentation_by: {"region" => "us"}, units: "3.0"},
          {presentation_by: {"region" => "eu"}, units: "4.0"}
        ])
      end
    end
  end

  describe "filter_breakdown" do
    let(:filter) { described_class::ALL }

    let(:charge) do
      build(:standard_charge, properties: {
        "presentation_group_keys" => [
          {"value" => "cloud", "options" => {"display_in_invoice" => true}},
          {"value" => "region", "options" => {"display_in_invoice" => false}}
        ]
      })
    end

    let(:fee) do
      build(
        :charge_fee,
        charge:,
        grouped_by: {},
        presentation_breakdowns: [
          build(:presentation_breakdown, presentation_by: {"cloud" => "aws", "region" => "us"}, units: 1),
          build(:presentation_breakdown, presentation_by: {"cloud" => nil, "region" => "eu"}, units: 2)
        ]
      )
    end

    let(:fees) { [fee] }

    context "when filter_breakdown is DISPLAY_IN_INVOICE" do
      let(:filter_breakdown) { described_class::DISPLAY_IN_INVOICE }

      it "includes only breakdowns that have a display_in_invoice key present" do
        expect(result).to eq([
          {presentation_by: {"cloud" => "aws"}, units: "1.0"}, {presentation_by: {"cloud" => nil}, units: "2.0"}
        ])
      end
    end

    context "when filter_breakdown is nil" do
      let(:filter_breakdown) { nil }

      it "includes all breakdowns regardless of display_in_invoice keys" do
        expect(result).to eq([
          {presentation_by: {"cloud" => "aws", "region" => "us"}, units: "1.0"},
          {presentation_by: {"cloud" => nil, "region" => "eu"}, units: "2.0"}
        ])
      end
    end
  end
end
