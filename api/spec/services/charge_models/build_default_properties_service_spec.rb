# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChargeModels::BuildDefaultPropertiesService do
  subject(:service) { described_class.new(charge_model) }

  describe "call" do
    context "when standard charge model" do
      let(:charge_model) { :standard }

      it "returns standard default properties" do
        expect(service.call).to eq({amount: "0"})
      end
    end

    context "when graduated charge model" do
      let(:charge_model) { :graduated }

      it "returns graduated default properties" do
        expect(service.call).to eq(
          {
            graduated_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0",
                flat_amount: "0"
              }
            ]
          }
        )
      end
    end

    context "when package charge model" do
      let(:charge_model) { :package }

      it "returns package default properties" do
        expect(service.call).to eq(
          {
            package_size: 1,
            amount: "0",
            free_units: 0
          }
        )
      end
    end

    context "when percentage charge model" do
      let(:charge_model) { :percentage }

      it "returns percentage default properties" do
        expect(service.call).to eq({rate: "0"})
      end
    end

    context "when volume charge model" do
      let(:charge_model) { :volume }

      it "returns volume default properties" do
        expect(service.call).to eq(
          {
            volume_ranges: [
              {
                from_value: 0,
                to_value: nil,
                per_unit_amount: "0",
                flat_amount: "0"
              }
            ]
          }
        )
      end
    end

    context "when graduated_percentage charge model" do
      let(:charge_model) { :graduated_percentage }

      it "returns graduated_percentage default properties" do
        expect(service.call).to eq(
          {
            graduated_percentage_ranges: [
              {
                from_value: 0,
                to_value: nil,
                rate: "0",
                fixed_amount: "0",
                flat_amount: "0"
              }
            ]
          }
        )
      end
    end

    context "when dynamic charge model" do
      let(:charge_model) { :dynamic }

      it "returns dynamic default properties" do
        expect(service.call).to eq({})
      end
    end
  end
end
