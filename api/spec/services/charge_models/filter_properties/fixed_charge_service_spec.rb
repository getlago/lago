# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::FilterProperties::FixedChargeService do
  subject(:filter_service) { described_class.new(chargeable:, properties:) }

  let(:charge_model) { nil }
  let(:chargeable) { build(:fixed_charge, charge_model:) }

  let(:properties) do
    {
      amount: 100,
      grouped_by: %w[location],
      graduated_ranges: [{from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"}],
      graduated_percentage_ranges: [{from_value: 0, to_value: 100, percentage: "2"}],
      free_units: 10,
      package_size: 10,
      rate: "0.0555",
      fixed_amount: "2",
      free_units_per_events: 10,
      free_units_per_total_aggregation: 10,
      per_transaction_max_amount: 100,
      per_transaction_min_amount: 10,
      volume_ranges: [{from_value: 0, to_value: 100, per_unit_amount: "2", flat_amount: "1"}],
      custom_properties:
    }
  end

  let(:custom_properties) { {custom: "prop"} }

  describe "#call" do
    context "without charge_model" do
      it "returns empty hash" do
        expect(filter_service.call.properties).to eq({})
      end
    end

    context "with standard charge_model" do
      let(:charge_model) { "standard" }

      it "filters the properties" do
        properties = filter_service.call.properties
        expect(properties.keys).to include("amount")
        expect(properties["amount"]).to eq(100)
      end
    end

    context "with graduated charge_model" do
      let(:charge_model) { "graduated" }

      it { expect(filter_service.call.properties.keys).to include("graduated_ranges") }
    end

    context "with volume charge_model" do
      let(:charge_model) { "volume" }

      it { expect(filter_service.call.properties.keys).to include("volume_ranges") }
    end
  end
end
