# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::MaxService do
  subject(:max_service) do
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
  let(:filters) { {grouped_by:, presentation_by:, matching_filters:, ignored_filters:} }

  let(:subscription) { create(:subscription) }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }
  let(:grouped_by) { nil }
  let(:presentation_by) { nil }
  let(:matching_filters) { {} }
  let(:ignored_filters) { [] }

  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "max_agg",
      field_name: "total_count"
    )
  end

  let(:charge) do
    create(
      :standard_charge,
      billable_metric:
    )
  end

  let(:from_datetime) { (Time.current - 1.month).beginning_of_day }
  let(:to_datetime) { Time.current.end_of_day }

  let(:events) do
    [
      create_list(
        :event,
        4,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: Time.zone.now - 2.days,
        properties: {
          total_count: rand(10)
        }
      ),

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: Time.zone.now - 1.day,
        properties: {
          total_count: 12
        }
      )
    ].flatten
  end

  before { events }

  it "aggregates the events" do
    result = max_service.aggregate

    expect(result.aggregation).to eq(12)
    expect(result.count).to eq(5)
  end

  context "when events are out of bounds" do
    let(:to_datetime) { Time.zone.now - 3.days }

    it "does not take events into account" do
      result = max_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
    end
  end

  context "when bypass_aggregation is set to true" do
    let(:bypass_aggregation) { true }

    it "returns a default empty result" do
      result = max_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.current_usage_units).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when properties is not found on events" do
    before do
      billable_metric.update!(field_name: "foo_bar")
    end

    it "counts as zero" do
      result = max_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
    end
  end

  context "when properties is a float" do
    let(:events) do
      [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: 14.2
          }
        )
      ]
    end

    it "aggregates the events" do
      result = max_service.aggregate

      expect(result.aggregation).to eq(14.2)
    end
  end

  context "when properties is not a number" do
    let(:events) do
      [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: "foo_bar"
          }
        )
      ]
    end

    it "ignores the event" do
      result = max_service.aggregate

      expect(result).to be_success
      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
    end
  end

  context "when properties is missing" do
    let(:events) do
      [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day
        )
      ]
    end

    it "ignore the event" do
      result = max_service.aggregate

      expect(result).to be_success
      expect(result.count).to eq(0)
      expect(result.aggregation).to eq(0)
    end
  end

  context "when filters are given" do
    let(:matching_filters) { {region: ["europe"]} }

    let(:events) do
      [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: 8,
            region: "europe"
          }
        ),

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: 12,
            region: "africa"
          }
        )
      ]
    end

    it "aggregates the events" do
      result = max_service.aggregate

      expect(result.aggregation).to eq(8)
      expect(result.count).to eq(1)
    end
  end

  describe ".per_event_aggregation" do
    it "aggregates per events" do
      result = max_service.per_event_aggregation

      expect(result.event_aggregation).to eq([0, 0, 0, 0, 12])
    end

    context "with grouped_by_values" do
      let(:event) { events.first }

      before do
        event.update!(properties: event.properties.merge(scheme: "visa"))
      end

      it "takes the groups into account" do
        result = max_service.per_event_aggregation(grouped_by_values: {"scheme" => "visa"})

        expect(result.event_aggregation).to eq([event.properties["total_count"]])
      end
    end
  end

  describe ".grouped_by_aggregation" do
    let(:grouped_by) { ["agent_name"] }
    let(:agent_names) { %w[aragorn frodo gimli legolas] }

    let(:events) do
      agent_names.map do |agent_name|
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: 12,
            agent_name:
          }
        )
      end + [
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {
            total_count: 12
          }
        )
      ]
    end

    it "returns a grouped aggregations" do
      result = max_service.aggregate

      expect(result.aggregations.count).to eq(5)

      result.aggregations.sort_by { |a| a.grouped_by["agent_name"] || "" }.each_with_index do |aggregation, index|
        expect(aggregation.aggregation).to eq(12)
        expect(aggregation.count).to eq(1)

        expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index - 1]) if index.positive?
      end
    end

    context "without events" do
      let(:events) { [] }

      it "returns an empty result" do
        result = max_service.aggregate

        expect(result.aggregations.count).to eq(1)

        aggregation = result.aggregations.first
        expect(aggregation.aggregation).to eq(0)
        expect(aggregation.count).to eq(0)
        expect(aggregation.grouped_by).to eq({"agent_name" => nil})
      end
    end

    context "when bypass_aggregation is set to true" do
      let(:bypass_aggregation) { true }

      it "returns an empty result" do
        result = max_service.aggregate

        expect(result.aggregations.count).to eq(1)

        aggregation = result.aggregations.first
        expect(aggregation.aggregation).to eq(0)
        expect(aggregation.count).to eq(0)
        expect(aggregation.grouped_by).to eq({"agent_name" => nil})
      end
    end
  end

  context "with presentation group keys" do
    let(:presentation_by) { ["cloud"] }

    let(:events) do
      [
        create_list(
          :event,
          3,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {total_count: 10, cloud: "aws"}
        ),
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: Time.zone.now - 1.day,
          properties: {total_count: 12, cloud: "gcp"}
        )
      ].flatten
    end

    it "returns the aggregations per group" do
      result = max_service.aggregate

      expect(result.breakdowns).to match_array([
        {groups: {"cloud" => "aws"}, value: 10},
        {groups: {"cloud" => "gcp"}, value: 12}
      ])
    end

    context "with grouped_by" do
      let(:grouped_by) { ["agent_name"] }

      let(:events) do
        [
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: Time.zone.now - 1.day,
            properties: {total_count: 2, agent_name: "frodo", cloud: "aws"}
          ),
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: Time.zone.now - 1.day,
            properties: {total_count: 7, agent_name: "frodo", cloud: "gcp"}
          ),
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: Time.zone.now - 1.day,
            properties: {total_count: 3, agent_name: "aragorn", cloud: "aws"}
          )
        ]
      end

      it "returns the aggregations per group" do
        result = max_service.aggregate

        expect(result.breakdowns).to match_array([
          {groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2},
          {groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 7},
          {groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 3}
        ])
      end
    end
  end
end
