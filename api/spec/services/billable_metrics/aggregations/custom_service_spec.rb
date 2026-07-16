# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::CustomService do
  subject(:custom_service) do
    described_class.new(
      event_store_class:,
      charge:,
      subscription:,
      boundaries: {
        from_datetime:,
        to_datetime:
      },
      filters:,
      bypass_aggregation:
    )
  end

  let(:event_store_class) { Events::Stores::PostgresStore }
  let(:bypass_aggregation) { false }
  let(:filters) { {grouped_by:, matching_filters:, ignored_filters:, event:} }

  let(:subscription) { create(:subscription) }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }

  let(:grouped_by) { nil }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }
  let(:event) { nil }

  let(:billable_metric) do
    create(:custom_billable_metric, organization:, custom_aggregator:)
  end
  let(:custom_aggregator) do
    <<~RUBY
      def aggregate(event, previous_state, aggregation_properties)
        previous_units = previous_state[:total_units]
        event_units = BigDecimal(event.properties['value'].to_s)
        storage_zone = event.properties['storage_zone']
        total_units = previous_units + event_units
        ranges = aggregation_properties['ranges']

        result_amount = ranges.each_with_object(0) do |range, amount|
          # Range was already reached
          next amount if range['to'] && previous_units > range['to']

          zone_amount = BigDecimal(range[storage_zone] || '0')

          if !range['to'] || total_units <= range['to']
            # Last matching range is reached
            units_to_use = if previous_units > range['from']
              # All new units are in the current range
              event_units
            else
              # Takes only the new units in the current range
              total_units - range['from']
            end
            break amount += zone_amount * units_to_use

          else
            # Range is not the last one
            units_to_use = if previous_units > range['from']
              # All remaining units in the range
              range['to'] - previous_units
            else
              # All units in the range
              range['to'] - range['from']
            end

            amount += zone_amount * units_to_use
          end

          amount
        end
        { total_units: total_units, amount: result_amount }
      end
    RUBY
  end

  let(:charge) { create(:standard_charge, billable_metric:, properties: charge_properties) }
  let(:charge_properties) do
    {
      amount: "10",
      custom_properties: {
        ranges: [
          {from: 0, to: 10, storage_eu: "0", storage_us: "0", storage_asia: "0"},
          {from: 10, to: 20, storage_eu: "0.10", storage_us: "0.20", storage_asia: "0.30"},
          {from: 20, to: nil, storage_eu: "0.20", storage_us: "0.30", storage_asia: "0.40"}
        ]
      }
    }
  end

  let(:from_datetime) { (Time.current - 1.month).beginning_of_day }
  let(:to_datetime) { Time.current.end_of_day }

  let(:event_list) do
    [
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        subscription:,
        customer:,
        timestamp: Time.zone.now - 4.days,
        properties: {value: 1, storage_zone: "storage_eu"}
      ),
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        subscription:,
        customer:,
        timestamp: Time.zone.now - 3.days,
        properties: {value: 10, storage_zone: "storage_asia"}
      ),
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        subscription:,
        customer:,
        timestamp: Time.zone.now - 2.days,
        properties: {value: 35, storage_zone: "storage_us"}
      )
    ]
  end

  before do
    event_list
  end

  it "aggregates the events" do
    result = custom_service.aggregate

    expect(result.aggregation).to eq(46)
    expect(result.count).to eq(3)
    expect(result.options).to eq({})
    expect(result.custom_aggregation).to eq({total_units: 46, amount: 8.1})
  end

  context "when there are no events" do
    let(:event_list) { [] }

    it "returns an empty state" do
      result = custom_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.options).to eq({})
      expect(result.custom_aggregation).to eq({total_units: 0, amount: 0})
    end
  end

  context "when bypass_aggregation is set to true" do
    let(:bypass_aggregation) { true }

    it "returns a default empty result" do
      result = custom_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.current_usage_units).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when the charge is payed in advance" do
    let(:charge) { create(:standard_charge, billable_metric:, properties: charge_properties, pay_in_advance: true) }

    let(:event_list) do
      [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          subscription:,
          customer:,
          timestamp: Time.zone.now - 4.days,
          properties: {value: 11, storage_zone: "storage_eu"}
        )
      ]
    end
    let(:event) { event_list.first }

    it "aggregates the events" do
      result = custom_service.aggregate

      expect(result.aggregation).to eq(11)
      expect(result.count).to eq(1)
      expect(result.options).to eq({})
      expect(result.custom_aggregation).to eq({total_units: 11.0, amount: 0.1})

      expect(result.pay_in_advance_aggregation).to eq(11)
      expect(result.current_aggregation).to eq(11.0)
      expect(result.max_aggregation).to eq(11.0)
      expect(result.units_applied).to eq(11.0)
      expect(result.current_amount).to eq(0.1)
    end

    context "with a cached aggregation" do
      before do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          external_subscription_id: subscription.external_id,
          timestamp: Time.zone.now - 4.days,
          current_aggregation: 11.0,
          max_aggregation: 11.0,
          current_amount: 0.1
        )
      end

      it "aggregates the events with the cached aggregation" do
        result = custom_service.aggregate

        expect(result.aggregation).to eq(11)
        expect(result.count).to eq(1)
        expect(result.options).to eq({})
        expect(result.custom_aggregation).to eq({total_units: 11.0, amount: 0.4})

        expect(result.pay_in_advance_aggregation).to eq(11)
        expect(result.current_aggregation).to eq(22.0)
        expect(result.max_aggregation).to eq(22.0)
        expect(result.units_applied).to eq(11.0)
        expect(result.current_amount).to eq(0.5)
      end
    end
  end

  context "when the charge is a standard with grouped by properties" do
    let(:grouped_by) { ["agent_name"] }
    let(:agent_names) { %w[aragorn frodo gimli legolas] }

    let(:event_list) do
      agent_names.map do |agent_name|
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 2.days,
          properties: {
            agent_name:,
            value: 11,
            storage_zone: "storage_eu"
          }
        )
      end + [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 2.days,
          properties: {value: 11, storage_zone: "storage_eu"}
        )
      ]
    end

    it "aggregates the events in groups" do
      result = custom_service.aggregate

      expect(result.aggregations.count).to eq(5)

      result.aggregations.sort_by { |a| a.grouped_by["agent_name"] || "" }.each_with_index do |aggregation, _index|
        expect(aggregation.aggregation).to eq(11)
        expect(aggregation.count).to eq(1)
        expect(aggregation.current_usage_units).to eq(11)
        expect(aggregation.custom_aggregation).to eq({total_units: 11, amount: 0.1})
      end
    end

    context "when bypass_aggregation is set to true" do
      let(:bypass_aggregation) { true }

      it "returns an empty result" do
        result = custom_service.aggregate

        expect(result.aggregations.count).to eq(1)

        aggregation = result.aggregations.first
        expect(aggregation.aggregation).to eq(0)
        expect(aggregation.count).to eq(0)
        expect(aggregation.grouped_by).to eq({"agent_name" => nil})
      end
    end
  end

  context "when the billable metric is recurring" do
    let(:billable_metric) do
      create(:custom_billable_metric, :recurring, organization:, custom_aggregator:)
    end

    it "aggregates the events" do
      result = custom_service.aggregate

      expect(result.aggregation).to eq(46)
      expect(result.count).to eq(3)
      expect(result.options).to eq({})
      expect(result.custom_aggregation).to eq({total_units: 46, amount: 8.1})
    end

    context "with a cached aggregation from a previous period" do
      before do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime - 1.day,
          current_aggregation: 11.0,
          max_aggregation: 11.0,
          current_amount: 0.1
        )
      end

      it "aggregates the events with the cached aggregation" do
        result = custom_service.aggregate

        expect(result.aggregation).to eq(57)
        expect(result.count).to eq(3)
        expect(result.options).to eq({})
        expect(result.custom_aggregation).to eq({total_units: 57.0, amount: 11.5})
      end
    end
  end
end
