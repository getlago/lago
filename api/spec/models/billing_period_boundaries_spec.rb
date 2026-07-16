# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingPeriodBoundaries do
  subject(:boundaries) do
    described_class.new(
      from_datetime:,
      to_datetime:,
      charges_from_datetime:,
      charges_to_datetime:,
      charges_duration:,
      fixed_charges_from_datetime:,
      fixed_charges_to_datetime:,
      fixed_charges_duration:,
      timestamp:
    )
  end

  let(:from_datetime) { timestamp.beginning_of_month }
  let(:to_datetime) { timestamp.end_of_month }
  let(:charges_from_datetime) { (timestamp - 1.month).beginning_of_month }
  let(:charges_to_datetime) { (timestamp - 1.month).end_of_month }
  let(:timestamp) { Time.current }
  let(:charges_duration) { charges_to_datetime - charges_from_datetime }
  let(:fixed_charges_from_datetime) { (timestamp - 2.months).beginning_of_month }
  let(:fixed_charges_to_datetime) { (timestamp - 2.months).end_of_month }
  let(:fixed_charges_duration) { fixed_charges_to_datetime - fixed_charges_from_datetime }

  describe "#to_h" do
    it "returns a hash with the boundaries" do
      expect(boundaries.to_h).to eq(
        "from_datetime" => from_datetime,
        "to_datetime" => to_datetime,
        "charges_from_datetime" => charges_from_datetime,
        "charges_to_datetime" => charges_to_datetime,
        "timestamp" => timestamp,
        "charges_duration" => charges_duration,
        "fixed_charges_from_datetime" => fixed_charges_from_datetime,
        "fixed_charges_to_datetime" => fixed_charges_to_datetime,
        "fixed_charges_duration" => fixed_charges_duration
      )
    end
  end

  describe ".from_fee" do
    let(:fee) { build(:charge_fee) }

    it "returns a BillingPeriodBoundaries instance" do
      instance = described_class.from_fee(fee)

      expect(instance).to be_a(described_class)
      expect(instance.from_datetime).to eq(fee.properties["from_datetime"])
      expect(instance.to_datetime).to eq(fee.properties["to_datetime"])
      expect(instance.charges_from_datetime).to eq(fee.properties["charges_from_datetime"])
      expect(instance.charges_to_datetime).to eq(fee.properties["charges_to_datetime"])
      expect(instance.charges_duration).to eq(fee.properties["charges_duration"])
      expect(instance.timestamp).to eq(fee.properties["timestamp"])
    end

    context "when fee belongs to a fixed charge" do
      let(:fee) { build(:fixed_charge_fee) }

      it "returns a BillingPeriodBoundaries instance" do
        instance = described_class.from_fee(fee)

        expect(instance).to be_a(described_class)
        expect(instance.from_datetime).to eq(fee.properties["from_datetime"])
        expect(instance.to_datetime).to eq(fee.properties["to_datetime"])
        expect(instance.charges_from_datetime).to eq(fee.properties["charges_from_datetime"])
        expect(instance.charges_to_datetime).to eq(fee.properties["charges_to_datetime"])
        expect(instance.charges_duration).to eq(fee.properties["charges_duration"])
        expect(instance.timestamp).to eq(fee.properties["timestamp"])
        expect(instance.fixed_charges_from_datetime).to eq(fee.properties["fixed_charges_from_datetime"])
        expect(instance.fixed_charges_to_datetime).to eq(fee.properties["fixed_charges_to_datetime"])
        expect(instance.fixed_charges_duration).to eq(fee.properties["fixed_charges_duration"])
      end
    end
  end
end
