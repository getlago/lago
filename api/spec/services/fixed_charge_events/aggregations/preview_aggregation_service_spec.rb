# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedChargeEvents::Aggregations::PreviewAggregationService do
  subject(:result) { described_class.call(fixed_charge:, subscription:, boundaries:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) do
    create(
      :fixed_charge,
      plan:,
      add_on:,
      charge_model: "standard",
      units: 5,
      properties: {amount: "10"}
    )
  end
  let(:subscription) do
    Subscription.new(
      organization_id: organization.id,
      customer:,
      plan:,
      subscription_at: Time.current,
      started_at: Time.current,
      billing_time: "calendar"
    )
  end
  let(:fixed_charges_from_datetime) { Time.current }
  let(:fixed_charges_to_datetime) { 1.month.from_now.to_datetime }
  let(:boundaries) do
    {
      "fixed_charges_from_datetime" => fixed_charges_from_datetime,
      "fixed_charges_to_datetime" => fixed_charges_to_datetime,
      "fixed_charges_duration" => 30
    }
  end

  it "returns the fixed_charge units" do
    expect(result).to be_success
    expect(result.aggregation).to eq(5)
    expect(result.full_units_number).to eq(5)
  end

  context "when fixed_charge has different units" do
    let(:fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:,
        charge_model: "graduated",
        units: 15,
        properties: {
          graduated_ranges: [
            {from_value: 0, to_value: 10, flat_amount: "0", per_unit_amount: "1"},
            {from_value: 11, to_value: nil, flat_amount: "0", per_unit_amount: "0.5"}
          ]
        }
      )
    end

    it "returns the fixed_charge units" do
      expect(result).to be_success
      expect(result.aggregation).to eq(15)
      expect(result.full_units_number).to eq(15)
    end
  end

  context "when fixed_charge has zero units" do
    let(:fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:,
        charge_model: "standard",
        units: 0,
        properties: {amount: "10"}
      )
    end

    it "returns zero" do
      expect(result).to be_success
      expect(result.aggregation).to eq(0)
      expect(result.full_units_number).to eq(0)
    end
  end

  context "when subscription is persisted" do
    let(:subscription) { create(:subscription, organization:, customer:, plan:) }

    it "still returns the fixed_charge units" do
      expect(result).to be_success
      expect(result.aggregation).to eq(5)
      expect(result.full_units_number).to eq(5)
    end
  end

  context "when fixed_charge is prorated" do
    let(:fixed_charge) do
      create(
        :fixed_charge,
        plan:,
        add_on:,
        charge_model: "standard",
        prorated: true,
        units: 100,
        properties: {amount: "10"}
      )
    end
    let(:fixed_charges_from_datetime) { Time.zone.parse("2024-06-01 00:00:00") }
    let(:fixed_charges_to_datetime) { Time.zone.parse("2024-12-31 23:59:59") }
    let(:boundaries) do
      {
        "fixed_charges_from_datetime" => fixed_charges_from_datetime,
        "fixed_charges_to_datetime" => fixed_charges_to_datetime,
        "fixed_charges_duration" => 365 # Full year
      }
    end

    it "returns prorated units based on billing period" do
      expect(result).to be_success

      # Billing period: June 1 - Dec 31 = 214 days
      # Full period: 365 days
      # Prorated units: 100 * (214 / 365) ≈ 58.63
      expect(result.aggregation).to be_within(0.01).of(58.63)
      expect(result.full_units_number).to eq(100)
    end

    context "with partial month billing period" do
      let(:fixed_charges_from_datetime) { Time.zone.parse("2024-03-15 00:00:00") }
      let(:fixed_charges_to_datetime) { Time.zone.parse("2024-03-31 23:59:59") }
      let(:boundaries) do
        {
          "fixed_charges_from_datetime" => fixed_charges_from_datetime,
          "fixed_charges_to_datetime" => fixed_charges_to_datetime,
          "fixed_charges_duration" => 31 # Full month (March)
        }
      end

      it "returns prorated units for partial period" do
        expect(result).to be_success

        # Billing period: March 15-31 = 17 days
        # Full period: 31 days (March)
        # Prorated units: 100 * (17 / 31) ≈ 54.84
        expect(result.aggregation).to be_within(0.01).of(54.84)
        expect(result.full_units_number).to eq(100)
      end
    end
  end

  context "when a subscription-level units override exists" do
    let(:subscription) { create(:subscription, organization:, customer:, plan:) }

    before do
      create(:subscription_fixed_charge_units_override, subscription:, fixed_charge:, units: 42)
    end

    it "returns the override units" do
      expect(result).to be_success
      expect(result.aggregation).to eq(42)
      expect(result.full_units_number).to eq(42)
    end

    context "when the fixed_charge is prorated" do
      let(:fixed_charge) do
        create(
          :fixed_charge,
          plan:,
          add_on:,
          charge_model: "standard",
          prorated: true,
          units: 100,
          properties: {amount: "10"}
        )
      end
      let(:fixed_charges_from_datetime) { Time.zone.parse("2024-03-15 00:00:00") }
      let(:fixed_charges_to_datetime) { Time.zone.parse("2024-03-31 23:59:59") }
      let(:boundaries) do
        {
          "fixed_charges_from_datetime" => fixed_charges_from_datetime,
          "fixed_charges_to_datetime" => fixed_charges_to_datetime,
          "fixed_charges_duration" => 31
        }
      end

      it "prorates against the override units" do
        expect(result).to be_success

        # Billing period: March 15-31 = 17 days
        # Full period: 31 days
        # Prorated units: 42 * (17 / 31) ≈ 23.03
        expect(result.aggregation).to be_within(0.01).of(23.03)
        expect(result.full_units_number).to eq(42)
      end
    end

    context "when the override has been discarded" do
      before do
        Subscription::FixedChargeUnitsOverride.unscoped.find_by(subscription:, fixed_charge:).discard!
      end

      it "falls back to the fixed_charge units" do
        expect(result).to be_success
        expect(result.aggregation).to eq(5)
        expect(result.full_units_number).to eq(5)
      end
    end
  end
end
