# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedChargeEvents::Aggregations::SimpleAggregationService do
  subject { described_class.new(fixed_charge:, subscription:, boundaries:) }

  let(:fixed_charge) { create(:fixed_charge) }
  let(:subscription) { create(:subscription) }
  let(:fixed_charges_from_datetime) { 9.days.ago }
  let(:fixed_charges_to_datetime) { Time.current }
  let(:events) { [] }
  let(:boundaries) do
    {
      "fixed_charges_from_datetime" => fixed_charges_from_datetime,
      "fixed_charges_to_datetime" => fixed_charges_to_datetime,
      "fixed_charges_duration" => 10
    }
  end

  before { events }

  context "when there are no events" do
    it "returns 0" do
      result = subject.call
      expect(result).to be_success
      expect(result.aggregation).to eq(0)
    end
  end

  context "when there are events only in this period" do
    let(:events) do
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 10, timestamp: 4.days.ago)
    end

    before { events }

    it "returns the simple aggregation" do
      result = subject.call
      expect(result).to be_success
      expect(result.aggregation).to eq(10)
    end
  end

  context "when there are events only in the previous period" do
    let(:events) do
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 10, timestamp: 30.days.ago, created_at: 30.days.ago)
    end

    before { events }

    it "returns the simple aggregation" do
      result = subject.call
      expect(result).to be_success
      expect(result.aggregation).to eq(10)
    end
  end

  context "when there are events in the previous period and in this" do
    let(:events) do
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 10, timestamp: 30.days.ago)
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 100, timestamp: 4.days.ago)
    end

    before { events }

    it "returns the simple aggregation" do
      result = subject.call
      expect(result).to be_success
      expect(result.aggregation).to eq(100)
    end
  end

  context "when last event is issued after event for the next billing period cancels event for the next billing period" do
    let(:events) do
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 20, timestamp: 10.days.ago, created_at: 10.days.ago)
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 10, timestamp: 5.days.from_now, created_at: 5.days.ago)
      create(:fixed_charge_event, fixed_charge:, subscription:, units: 100, timestamp: Time.current, created_at: Time.current)
    end

    context "when aggregating for the current period" do
      it "returns the simple aggregation" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(100)
      end
    end

    context "when aggregating for the next billing period" do
      let(:fixed_charges_from_datetime) { 1.day.from_now } # total duration is 10 days
      let(:fixed_charges_to_datetime) { 10.days.from_now }

      it "returns the simple aggregation erasing the event for the next billing period created before last event of this billing period" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(100)
      end
    end
  end

  context "when having a lot of events issued for this and following billing periods" do
    let(:events_matrix) do
      [
        {units: 30, timestamp: Date.new(2024, 1, 1), created_at: Date.new(2025, 1, 1)}, # 1 Jan this year for 1 Jan last year
        {units: 10, timestamp: Date.new(2025, 1, 1), created_at: Date.new(2025, 1, 9)}, # 9 Jan for 1 Jan
        {units: 5, timestamp: Date.new(2025, 2, 1), created_at: Date.new(2025, 1, 5)}, # 5 Jan for 1 Feb
        {units: 77, timestamp: Date.new(2025, 1, 22), created_at: Date.new(2025, 1, 7)}, # 7 Jan for 22 Jan
        {units: 7, timestamp: Date.new(2025, 1, 20), created_at: Date.new(2025, 1, 10)}, # 10 Jan for 20 Jan
        {units: 12, timestamp: Date.new(2025, 3, 1), created_at: Date.new(2025, 1, 20)}, # 20 Jan for 1 Mar
        {units: 70, timestamp: Date.new(2025, 2, 10), created_at: Date.new(2025, 1, 30)} # 30 Jan for 10 Feb
      ]
    end

    let(:events) do
      events_matrix.map do |event|
        create(:fixed_charge_event, fixed_charge:, subscription:, **event)
      end
    end

    context "when billing period is December last year" do # event is created after billed billing period for timestamp before the billing period
      let(:fixed_charges_from_datetime) { Date.new(2024, 12, 1) }
      let(:fixed_charges_to_datetime) { Date.new(2024, 12, 31) }
      let(:fixed_charges_duration) { 31 }

      it "returns the simple aggregation" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(30)
      end
    end

    context "when billing period is January" do
      let(:fixed_charges_from_datetime) { Date.new(2025, 1, 1) }
      let(:fixed_charges_to_datetime) { Date.new(2025, 1, 31) }

      it "returns the simple aggregation with latest created at and timestamp" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(7)
      end
    end

    context "when billing period is February" do
      let(:fixed_charges_from_datetime) { Date.new(2025, 2, 1) }
      let(:fixed_charges_to_datetime) { Date.new(2025, 2, 28) }

      it "returns the simple aggregation with latest created at and timestamp" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(70)
      end
    end

    context "when billing period is March" do
      let(:fixed_charges_from_datetime) { Date.new(2025, 3, 1) }
      let(:fixed_charges_to_datetime) { Date.new(2025, 3, 31) }

      it "returns the simple aggregation with latest created at and timestamp" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(70)
      end
    end
  end

  context "when an override was created after subscription started" do
    let(:parent_charge) { create(:fixed_charge) }
    let(:fixed_charge) { create(:fixed_charge, parent: parent_charge) }
    let(:parent_event) { create(:fixed_charge_event, fixed_charge: parent_charge, subscription:, units: 10, timestamp: 12.days.ago, created_at: 10.days.ago) }

    before { parent_event }

    context "when there are only events for the parent charge" do
      it "returns the simple aggregation" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(10)
      end
    end

    context "when there are events for the parent and child charges" do
      let(:child_event) { create(:fixed_charge_event, fixed_charge:, subscription:, units: 5, timestamp: 8.days.ago, created_at: 10.days.ago) }

      before { child_event }

      it "returns the simple aggregation" do
        result = subject.call
        expect(result).to be_success
        expect(result.aggregation).to eq(5)
        expect(result.full_units_number).to eq(5)
      end
    end
  end
end
