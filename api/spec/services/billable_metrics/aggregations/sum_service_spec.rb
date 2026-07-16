# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::SumService, transaction: false do
  subject(:sum_service) do
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
  let(:filters) do
    {event: pay_in_advance_event, grouped_by:, presentation_by:, charge_filter:, matching_filters:, ignored_filters:}
  end

  let(:subscription) { create(:subscription, started_at: Time.current.beginning_of_month - 6.months) }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }
  let(:grouped_by) { nil }
  let(:presentation_by) { nil }
  let(:charge_filter) { nil }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }

  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "sum_agg",
      field_name: "total_count"
    )
  end

  let(:charge) do
    create(
      :standard_charge,
      billable_metric:
    )
  end

  let(:from_datetime) { subscription.started_at + 5.months }
  let(:to_datetime) { subscription.started_at + 6.months }
  let(:pay_in_advance_event) { nil }
  let(:options) do
    {free_units_per_events: 2, free_units_per_total_aggregation: 30}
  end

  let(:old_events) do
    create_list(
      :event,
      2,
      organization_id: organization.id,
      code: billable_metric.code,
      customer:,
      subscription:,
      timestamp: subscription.started_at + 3.months,
      properties: {
        total_count: 2.5
      }
    )
  end

  let(:latest_events) do
    create_list(
      :event,
      4,
      organization_id: organization.id,
      code: billable_metric.code,
      customer:,
      subscription:,
      timestamp: to_datetime - 1.day,
      properties: {
        total_count: 12
      }
    )
  end

  before do
    old_events
    latest_events
  end

  it "aggregates the events" do
    result = sum_service.aggregate(options:)

    expect(result.aggregation).to eq(48)
    expect(result.pay_in_advance_aggregation).to be_zero
    expect(result.count).to eq(4)
    expect(result.options).to eq({running_total: [12, 24]})
  end

  context "when billable metric is recurring" do
    before { billable_metric.update!(recurring: true) }

    it "aggregates the events" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(53)
      expect(result.pay_in_advance_aggregation).to be_zero
      expect(result.count).to eq(6)
      expect(result.options).to eq({running_total: [2.5, 5]})
    end
  end

  context "when a sum result is injected" do
    let(:injected_sum_result) { Events::Stores::BaseStore::AggregationResult.new(value: 999, events_count: 7) }

    before { sum_service.injected_sum_result = injected_sum_result }

    it "uses the injected result instead of querying the event store" do
      result = sum_service.aggregate(options: {})

      expect(result.aggregation).to eq(999)
      expect(result.count).to eq(7)
    end
  end

  context "when a grouped sum result is injected" do
    let(:grouped_by) { %w[region] }
    let(:injected_grouped_sum_result) do
      [
        Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "us"}, value: 100, events_count: 3),
        Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "eu"}, value: 50, events_count: 2)
      ]
    end

    before { sum_service.injected_grouped_sum_result = injected_grouped_sum_result }

    it "builds the group results from the injected values" do
      result = sum_service.aggregate(options: {})

      expect(result.aggregations.map { |agg| [agg.grouped_by, agg.aggregation, agg.count] }).to match_array(
        [
          [{"region" => "us"}, 100, 3],
          [{"region" => "eu"}, 50, 2]
        ]
      )
    end

    context "when the injected grouped result is blank" do
      let(:injected_grouped_sum_result) { [] }

      it "returns empty results" do
        result = sum_service.aggregate(options: {})

        expect(result.aggregations.map(&:aggregation)).to eq([0])
      end
    end
  end

  context "when options are not present" do
    let(:options) { {} }

    it "returns an empty running total array" do
      result = sum_service.aggregate(options:)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when option values are nil" do
    let(:options) do
      {free_units_per_events: nil, free_units_per_total_aggregation: nil}
    end

    it "returns an empty running total array" do
      result = sum_service.aggregate(options:)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when free_units_per_events is nil" do
    let(:options) do
      {free_units_per_events: nil, free_units_per_total_aggregation: 30}
    end

    it "returns running total based on per total aggregation" do
      result = sum_service.aggregate(options:)
      expect(result.options).to eq({running_total: [12, 24, 36]})
    end
  end

  context "when free_units_per_total_aggregation is nil" do
    let(:options) do
      {free_units_per_events: 2, free_units_per_total_aggregation: nil}
    end

    it "returns running total based on per events" do
      result = sum_service.aggregate(options:)
      expect(result.options).to eq({running_total: [12, 24]})
    end
  end

  context "when charge is dynamic" do
    let(:charge) { create(:dynamic_charge, billable_metric:) }

    it "computes the precise_total_amount_cents" do
      result = sum_service.aggregate(options:)
      expect(result.precise_total_amount_cents).to be_zero
    end

    context "with events that specify a precise_total_amount_cents" do
      let(:old_events) do
        create_list(
          :event,
          2,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: subscription.started_at + 3.months,
          properties: {
            total_count: 2.5
          },
          precise_total_amount_cents: 12
        )
      end
      let(:latest_events) do
        create_list(
          :event,
          4,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {
            total_count: 12
          },
          precise_total_amount_cents: 10
        )
      end

      it "computes the precise_total_amount_cents" do
        result = sum_service.aggregate(options:)
        expect(result.aggregation).to eq(4 * 12)
        expect(result.precise_total_amount_cents).to eq(4 * 10)
      end
    end

    context "when filters are given" do
      let(:matching_filters) { {region: ["europe"]} }

      before do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {
            total_count: 12,
            region: "europe"
          },
          precise_total_amount_cents: 5
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {
            total_count: 8,
            region: "europe"
          },
          precise_total_amount_cents: 7
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {
            total_count: 12,
            region: "africa"
          },
          precise_total_amount_cents: 9
        )
      end

      it "aggregates the events matching the filter" do
        result = sum_service.aggregate(options:)

        expect(result.aggregation).to eq(20)
        expect(result.count).to eq(2)
        expect(result.precise_total_amount_cents).to eq(12)
        expect(result.options).to eq({running_total: [12, 20]})
      end
    end
  end

  context "when events are out of bounds" do
    let(:latest_events) do
      create_list(
        :event,
        4,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime + 1.day,
        properties: {
          total_count: 12
        }
      )
    end

    it "does not take events into account" do
      result = sum_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when properties is not found on events" do
    before do
      billable_metric.update!(field_name: "foo_bar")
    end

    it "counts as zero" do
      result = sum_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "when properties is a float" do
    before do
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 4.5
        }
      )
    end

    it "aggregates the events" do
      result = sum_service.aggregate

      expect(result.aggregation).to eq(52.5)
    end
  end

  context "when properties is not a number" do
    before do
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: "foo_bar"
        }
      )
    end

    it "ignores the event" do
      result = sum_service.aggregate

      expect(result).to be_success
      expect(result.aggregation).to eq(48)
      expect(result.count).to eq(4)
    end
  end

  context "when current usage context and charge is pay in advance" do
    let(:options) do
      {is_pay_in_advance: true, is_current_usage: true}
    end

    let(:latest_events) do
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 3.days,
        properties: {
          total_count: 4
        }
      )
    end

    let(:cached_aggregation) do
      create(
        :cached_aggregation,
        organization:,
        charge:,
        event_transaction_id: latest_events.transaction_id,
        external_subscription_id: subscription.external_id,
        timestamp: to_datetime - 3.days,
        current_aggregation: "4",
        max_aggregation: "6"
      )
    end

    before do
      billable_metric.update!(recurring: true)
      cached_aggregation
    end

    it "returns period maximum as aggregation" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(11)
    end

    context "when cached aggregation does not exist" do
      let(:latest_events) { nil }
      let(:cached_aggregation) { nil }

      before { billable_metric.update!(recurring: false) }

      it "returns zero as aggregation" do
        result = sum_service.aggregate(options:)

        expect(result.aggregation).to eq(0)
      end
    end
  end

  context "with non persisted event" do
    let(:options) do
      {free_units_per_events: 4, free_units_per_total_aggregation: 30, is_pay_in_advance: true}
    end

    let(:latest_events) do
      create_list(
        :event,
        2,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 12
        }
      )
    end

    let(:event) do
      build(
        :common_event,
        subscription:,
        organization:,
        billable_metric:,
        properties: {
          billable_metric.field_name => 10
        },
        persisted: false
      )
    end

    let(:filters) { {grouped_by:, matching_filters:, ignored_filters:, event:} }

    it "returns period maximum as aggregation" do
      result = sum_service.aggregate(options:)

      expect(result.options[:running_total]).to eq([12.0, 24.0, 34.0])
    end
  end

  context "when filters are given" do
    let(:matching_filters) { {region: ["europe"]} }

    before do
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 12,
          region: "europe"
        }
      )

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 8,
          region: "europe"
        }
      )

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 12,
          region: "africa"
        }
      )
    end

    it "aggregates the events" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(20)
      expect(result.count).to eq(2)
      expect(result.options).to eq({running_total: [12, 20]})
    end
  end

  context "when filter is given" do
    let(:filter) do
      create(:billable_metric_filter, billable_metric:, key: "region", values: ["north america", "europe", "africa"])
    end
    let(:matching_filters) { {"region" => ["europe"]} }
    let(:ignored_filters) { [] }
    let(:charge_filter) { create(:charge_filter, charge:) }
    let(:filter_value) do
      create(
        :charge_filter_value,
        charge_filter:,
        billable_metric_filter: filter,
        values: ["europe"]
      )
    end

    before do
      filter_value

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 12,
          region: "europe"
        }
      )

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 8,
          region: "europe"
        }
      )

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 1.day,
        properties: {
          total_count: 12,
          region: "africa"
        }
      )
    end

    it "aggregates the events" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(20)
      expect(result.count).to eq(2)
      expect(result.options).to eq({running_total: [12, 20]})
    end
  end

  context "when subscription was upgraded in the period" do
    let(:old_subscription) do
      create(
        :subscription,
        external_id: subscription.external_id,
        organization:,
        customer:,
        started_at: from_datetime - 10.days,
        terminated_at: from_datetime,
        status: :terminated
      )
    end

    before do
      old_subscription
      subscription.update!(previous_subscription: old_subscription)
      billable_metric.update!(recurring: true)
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription: old_subscription,
        timestamp: from_datetime - 5.days,
        properties: {
          total_count: 10
        }
      )
    end

    it "returns the correct number" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(63)
    end
  end

  context "when event is given" do
    let(:old_events) { nil }
    let(:latest_events) { nil }
    let(:pay_in_advance_event) do
      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        customer:,
        subscription:,
        timestamp: to_datetime - 2.days,
        properties:
      )
    end

    let(:properties) { {total_count: 10} }

    it "assigns a pay_in_advance aggregation" do
      result = sum_service.aggregate

      expect(result.pay_in_advance_aggregation).to eq(10)
    end

    context "with presentation group keys" do
      let(:presentation_by) { ["cloud", "region"] }
      let(:properties) { {"total_count" => 10, "cloud" => "aws", "region" => "eu"} }

      it "assigns pay_in_advance_breakdowns based on the pay_in_advance event" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_breakdowns).to eq([
          {groups: {"cloud" => "aws", "region" => "eu"}, value: 10}
        ])
      end
    end

    context "when current period aggregation is greater than period maximum" do
      let(:latest_events) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 3.days,
          properties: {
            total_count: -6
          }
        )
      end

      let(:cached_aggregation) do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 3.days,
          current_aggregation: "4",
          max_aggregation: "10"
        )
      end

      before { cached_aggregation }

      it "assigns a pay_in_advance aggregation" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to eq(4)
      end
    end

    context "when current period aggregation is less than period maximum" do
      let(:properties) { {total_count: -2} }
      let(:latest_events) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 3.days,
          properties: {
            total_count: -6
          }
        )
      end

      let(:cached_aggregation) do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          event_transaction_id: latest_events.transaction_id,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 3.days,
          current_aggregation: "4",
          max_aggregation: "10"
        )
      end

      before { cached_aggregation }

      it "assigns a pay_in_advance aggregation" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to eq(0)
      end
    end

    context "when properties is a float" do
      let(:properties) { {total_count: 12.4} }

      it "assigns a pay_in_advance aggregation" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to eq(12.4)
      end
    end

    context "when event property does not match metric field name" do
      let(:properties) { {final_count: 10} }

      it "assigns 0 as pay_in_advance aggregation" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to be_zero
      end
    end

    context "when event is missing properties" do
      let(:properties) { {} }

      it "assigns 0 as pay_in_advance aggregation" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to be_zero
      end
    end

    context "when a precise_total_amount_cents is present" do
      let(:charge) do
        create(
          :dynamic_charge,
          billable_metric:
        )
      end

      let(:pay_in_advance_event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 2.days,
          properties:,
          precise_total_amount_cents: 1234.02
        )
      end

      it "computes the precise_total_amount_cents" do
        result = sum_service.aggregate

        expect(result.pay_in_advance_aggregation).to eq(10)
        expect(result.precise_total_amount_cents).to eq(1234.02)
        expect(result.pay_in_advance_precise_total_amount_cents).to eq(1234.02)
      end
    end
  end

  context "when rounding is configured" do
    let(:billable_metric) do
      create(
        :billable_metric,
        organization:,
        aggregation_type: "sum_agg",
        field_name: "total_count",
        rounding_function: "ceil",
        rounding_precision: 2
      )
    end

    before do
      latest_events.last.update!(properties: {total_count: 12.434})
    end

    it "aggregates the events" do
      result = sum_service.aggregate(options:)

      expect(result.aggregation).to eq(48.44)
    end
  end

  context "when bypass_aggregation is set to true" do
    let(:bypass_aggregation) { true }

    it "returns a default empty result" do
      result = sum_service.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.current_usage_units).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  describe ".per_event_aggregation" do
    it "aggregates per events" do
      result = sum_service.per_event_aggregation

      expect(result.event_aggregation).to eq([12, 12, 12, 12])
    end

    context "with grouped_by_values" do
      let(:event) { latest_events.first }

      before do
        event.update!(properties: event.properties.merge(scheme: "visa"))
      end

      it "takes the groups into account" do
        result = sum_service.per_event_aggregation(grouped_by_values: {"scheme" => "visa"})

        expect(result.event_aggregation).to eq([12])
      end
    end

    context "when including event value" do
      let(:event) do
        build(
          :common_event,
          subscription:,
          organization:,
          billable_metric:,
          properties: {
            billable_metric.field_name => 10
          }
        )
      end

      let(:filters) { {grouped_by:, matching_filters:, ignored_filters:, event:} }

      it "includes the event value in the result" do
        result = sum_service.per_event_aggregation(include_event_value: true)

        expect(result.event_aggregation).to eq([12, 12, 12, 12, 10])
      end
    end
  end

  describe ".grouped_by aggregation" do
    let(:grouped_by) { ["agent_name"] }

    let(:agent_names) { %w[aragorn frodo gimli legolas] }

    let(:old_events) { [] }

    let(:latest_events) do
      agent_names.map do |agent_name|
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {
            total_count: 12,
            agent_name:
          }
        )
      end
    end

    it "returns a grouped aggregations" do
      result = sum_service.aggregate(options:)

      expect(result.aggregations.count).to eq(4)

      result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
        expect(aggregation.aggregation).to eq(12)
        expect(aggregation.count).to eq(1)
        expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
        expect(aggregation.options[:running_total]).to eq([12])
      end
    end

    context "without events" do
      let(:latest_events) { [] }

      it "returns an empty result" do
        result = sum_service.aggregate(options:)

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
        result = sum_service.aggregate

        expect(result.aggregations.count).to eq(1)

        aggregation = result.aggregations.first
        expect(aggregation.aggregation).to eq(0)
        expect(aggregation.count).to eq(0)
        expect(aggregation.grouped_by).to eq({"agent_name" => nil})
      end
    end

    context "when current usage context and charge is pay in advance" do
      let(:options) do
        {is_pay_in_advance: true, is_current_usage: true}
      end

      let(:cached_aggregation) do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 3.days,
          current_aggregation: "4",
          max_aggregation: "6"
        )
      end

      before do
        billable_metric.update!(recurring: true)
        cached_aggregation
      end

      it "returns period maximum as aggregation" do
        result = sum_service.aggregate(options:)

        expect(result.aggregations.count).to eq(4)

        result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
          expect(aggregation.aggregation).to eq(12)
          expect(aggregation.count).to eq(1)
          expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
        end
      end

      context "when cached aggregation does not exist" do
        let(:latest_events) { nil }
        let(:cached_aggregation) { nil }

        before { billable_metric.update!(recurring: false) }

        it "returns an empty result" do
          result = sum_service.aggregate(options:)

          expect(result.aggregations.count).to eq(1)

          aggregation = result.aggregations.first
          expect(aggregation.aggregation).to eq(0)
          expect(aggregation.count).to eq(0)
          expect(aggregation.current_usage_units).to eq(0)
          expect(aggregation.grouped_by).to eq({"agent_name" => nil})
        end
      end
    end

    context "when rounding is configured" do
      let(:billable_metric) do
        create(
          :billable_metric,
          organization:,
          aggregation_type: "sum_agg",
          field_name: "total_count",
          rounding_function: "ceil",
          rounding_precision: 2
        )
      end

      let(:last_event) do
        latest_events.last.tap do |e|
          e.update!(properties: {total_count: 12.434, agent_name: e.properties["agent_name"]})
        end
      end

      before { last_event }

      it "aggregates the events" do
        result = sum_service.aggregate(options:)

        expect(result.aggregations.count).to eq(4)

        result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
          if aggregation.grouped_by["agent_name"] == last_event.properties["agent_name"]
            expect(aggregation.aggregation).to eq(12.44)
          else
            expect(aggregation.aggregation).to eq(12)
          end
          expect(aggregation.count).to eq(1)
          expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
        end
      end
    end

    context "with free units per events" do
      it "returns a result with free units" do
        result = sum_service.aggregate(options: {free_units_per_events: 10})

        expect(result.aggregations.count).to eq(4)

        result.aggregations.each_with_index do |aggregation, index|
          expect(aggregation.options[:running_total]).to eq([12])
        end
      end
    end
  end

  context "with presentation group keys" do
    let(:presentation_by) { ["cloud"] }
    let(:old_events) { [] }

    let(:latest_events) do
      [
        create_list(
          :event,
          3,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {total_count: 10, cloud: "aws"}
        ),
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          customer:,
          subscription:,
          timestamp: to_datetime - 1.day,
          properties: {total_count: 12, cloud: "gcp"}
        )
      ].flatten
    end

    it "returns the aggregations per group" do
      result = sum_service.aggregate

      expect(result.breakdowns).to match_array([
        {groups: {"cloud" => "aws"}, value: 30},
        {groups: {"cloud" => "gcp"}, value: 12}
      ])
    end

    context "with grouped_by" do
      let(:grouped_by) { ["agent_name"] }

      let(:latest_events) do
        [
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: to_datetime - 1.day,
            properties: {total_count: 2, agent_name: "frodo", cloud: "aws"}
          ),
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: to_datetime - 1.day,
            properties: {total_count: 7, agent_name: "frodo", cloud: "gcp"}
          ),
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            customer:,
            subscription:,
            timestamp: to_datetime - 1.day,
            properties: {total_count: 3, agent_name: "aragorn", cloud: "aws"}
          )
        ]
      end

      it "returns the aggregations per group" do
        result = sum_service.aggregate

        expect(result.breakdowns).to match_array([
          {groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2},
          {groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 7},
          {groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 3}
        ])
      end
    end
  end
end
