# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::Aggregations::WeightedSumService, transaction: false do
  subject(:aggregator) do
    described_class.new(
      event_store_class:,
      charge:,
      subscription:,
      boundaries: {
        from_datetime:,
        to_datetime:,
        charges_duration:
      },
      filters:,
      bypass_aggregation:
    )
  end

  let(:event_store_class) { Events::Stores::PostgresStore }
  let(:bypass_aggregation) { false }
  let(:filters) { {grouped_by:, presentation_by:, matching_filters:, ignored_filters:} }

  let(:subscription) { create(:subscription, started_at: DateTime.parse("2023-04-01 22:22:22")) }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }
  let(:grouped_by) { nil }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }
  let(:presentation_by) { nil }

  let(:billable_metric) { create(:weighted_sum_billable_metric, organization:) }

  let(:charge) do
    create(
      :standard_charge,
      billable_metric:
    )
  end

  let(:from_datetime) { Time.zone.parse("2023-08-01 00:00:00.000") }
  let(:to_datetime) { Time.zone.parse("2023-08-31 23:59:59.999") }
  let(:charges_duration) { 31 }

  let(:events_values) do
    [
      {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2},
      {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3},
      {timestamp: Time.zone.parse("2023-08-01 01:30:00"), value: 1},
      {timestamp: Time.zone.parse("2023-08-01 02:00:00"), value: -4},
      {timestamp: Time.zone.parse("2023-08-01 04:00:00"), value: -2},
      {timestamp: Time.zone.parse("2023-08-01 05:00:00"), value: 10},
      {timestamp: Time.zone.parse("2023-08-01 05:30:00"), value: -10}
    ]
  end

  before do
    events_values.each do |values|
      properties = {value: values[:value]}
      properties[:region] = values[:region] if values[:region]
      properties[:agent_name] = values[:agent_name] if values[:agent_name]

      create(
        :event,
        organization_id: organization.id,
        code: billable_metric.code,
        subscription:,
        customer:,
        timestamp: values[:timestamp],
        properties:
      )
    end
  end

  it "aggregates the events" do
    result = aggregator.aggregate

    expect(result.aggregation.round(5).to_s).to eq("0.02218")
    expect(result.count).to eq(7)
  end

  context "when using presentation_by" do
    let(:presentation_by) { ["region"] }

    let(:events_values) do
      [
        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2, region: "eu"},
        {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3, region: "us"},
        {timestamp: Time.zone.parse("2023-08-01 02:00:00"), value: -1, region: "eu"}
      ]
    end

    it "returns aggregations per group" do
      result = aggregator.aggregate

      region_eu = result.breakdowns.find { |b| b[:groups]["region"] == "eu" }
      expect(region_eu[:value].round(5).to_s).to eq("1.00269")

      region_us = result.breakdowns.find { |b| b[:groups]["region"] == "us" }
      expect(region_us[:value].round(5).to_s).to eq("2.99597")
    end
  end

  context "with a single event" do
    let(:events_values) do
      [
        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 1000}
      ]
    end

    it "aggregates the events" do
      result = aggregator.aggregate

      expect(result.aggregation.round(5).to_s).to eq("1000.0")
      expect(result.count).to eq(1)
    end
  end

  context "with no events" do
    let(:events_values) { [] }

    it "aggregates the events" do
      result = aggregator.aggregate

      expect(result.aggregation.round(5).to_s).to eq("0.0")
      expect(result.count).to eq(0)
      expect(result.options).to eq({})
    end
  end

  context "when bypass_aggregation is set to true" do
    let(:bypass_aggregation) { true }

    it "returns a default empty result" do
      result = aggregator.aggregate

      expect(result.aggregation).to eq(0)
      expect(result.count).to eq(0)
      expect(result.current_usage_units).to eq(0)
      expect(result.options).to eq({running_total: []})
    end
  end

  context "with events with the same timestamp" do
    let(:events_values) do
      [
        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3},
        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3}
      ]
    end

    it "aggregates the events" do
      result = aggregator.aggregate

      expect(result.aggregation).to eq(6)
      expect(result.count).to eq(2)
    end
  end

  context "when billable metric is recurring" do
    let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

    let(:events_values) { [] }

    let(:cached_aggregation) do
      create(
        :cached_aggregation,
        charge:,
        organization:,
        external_subscription_id: subscription.external_id,
        timestamp: from_datetime - 1.day,
        current_aggregation: 1000
      )
    end

    before { cached_aggregation }

    it "uses the persisted recurring value as initial value" do
      result = aggregator.aggregate

      expect(result.aggregation.to_s).to eq("1000.0")
      expect(result.count).to eq(0)
      expect(result.variation).to eq(0)
      expect(result.total_aggregated_units).to eq(1000)
      expect(result.recurring_updated_at).to eq(from_datetime)
    end

    context "when using presentation_by with no current events and zero initial value" do
      let(:presentation_by) { ["region"] }
      let(:events_values) { [] }
      let(:cached_aggregation) do
        create(
          :cached_aggregation,
          charge:,
          organization:,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime - 1.day,
          current_aggregation: 0,
          presentation_breakdowns: [{"groups" => {"region" => "eu"}, "value" => "100.0"}]
        )
      end

      it "falls back to cached presentation breakdowns" do
        result = aggregator.aggregate

        expect(result.breakdowns).to eq([{groups: {"region" => "eu"}, value: 100.to_d}])
      end
    end

    context "without cached_aggregation" do
      let(:cached_aggregation) {}

      it "falls back on 0" do
        result = aggregator.aggregate

        expect(result.aggregation.round(5).to_s).to eq("0.0")
        expect(result.count).to eq(0)
        expect(result.variation).to eq(0)
        expect(result.total_aggregated_units).to eq(0)
        expect(result.recurring_updated_at).to eq(from_datetime)
      end

      context "with events attached to a previous subcription" do
        let(:previous_subscription) do
          create(
            :subscription,
            :terminated,
            started_at: DateTime.parse("2022-01-01 22:22:22"),
            terminated_at: DateTime.parse("2023-04-01 22:22:21")
          )
        end

        let(:customer) { previous_subscription.customer }

        let(:subscription) do
          create(
            :subscription,
            started_at: DateTime.parse("2023-04-01 22:22:22"),
            previous_subscription:,
            customer:,
            external_id: previous_subscription.external_id
          )
        end

        before do
          subscription

          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            subscription: previous_subscription,
            customer:,
            timestamp: Time.zone.parse("2023-03-01 22:22:22"),
            properties: {value: 10}
          )
        end

        it "uses previous events as latest value" do
          result = aggregator.aggregate

          expect(result.aggregation.round(5).to_s).to eq("10.0")
          expect(result.count).to eq(0)
          expect(result.variation).to eq(0)
          expect(result.total_aggregated_units).to eq(10)
          expect(result.recurring_updated_at).to eq(from_datetime)
        end

        context "when using presentation_by" do
          let(:presentation_by) { ["region"] }

          let(:events_values) do
            [
              {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2, region: "eu"},
              {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3, region: "eu"}
            ]
          end

          it "returns aggregations per group" do
            result = aggregator.aggregate

            region_eu = result.breakdowns.find { |b| b[:groups]["region"] == "eu" }
            expect(region_eu[:value].round(5).to_s).to eq("4.99597")

            region_nil = result.breakdowns.find { |b| b[:groups]["region"].nil? }
            expect(region_nil[:value].round(5).to_s).to eq("10.0")
          end
        end
      end
    end

    context "with events" do
      let(:events_values) do
        [
          {timestamp: DateTime.parse("2023-08-01 00:00:00.000"), value: 2},
          {timestamp: DateTime.parse("2023-08-01 01:00:00"), value: 3},
          {timestamp: DateTime.parse("2023-08-01 01:30:00"), value: 1},
          {timestamp: DateTime.parse("2023-08-01 02:00:00"), value: -4},
          {timestamp: DateTime.parse("2023-08-01 04:00:00"), value: -2},
          {timestamp: DateTime.parse("2023-08-01 05:00:00"), value: 10},
          {timestamp: DateTime.parse("2023-08-01 05:30:00"), value: -10}
        ]
      end

      it "aggregates the events" do
        result = aggregator.aggregate

        expect(result.aggregation.round(5).to_s).to eq("1000.02218")
        expect(result.count).to eq(7)
        expect(result.variation).to eq(0)
        expect(result.total_aggregated_units).to eq(1000)
        expect(result.recurring_updated_at).to eq("2023-08-01 05:30:00")
      end
    end
  end

  context "with filters" do
    let(:matching_filters) { {region: ["europe"]} }

    let(:events_values) do
      [
        {timestamp: DateTime.parse("2023-08-01 00:00:00.000"), value: 1000, region: "europe"}
      ]
    end

    it "aggregates the events" do
      result = aggregator.aggregate

      expect(result.aggregation.to_s).to eq("1000.0")
      expect(result.count).to eq(1)
    end
  end

  describe ".grouped_by aggregation" do
    let(:grouped_by) { ["agent_name"] }
    let(:agent_names) { %w[aragorn frodo] }

    let(:events_values) do
      [
        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 01:30:00"), value: 1, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 02:00:00"), value: -4, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 04:00:00"), value: -2, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 05:00:00"), value: 10, agent_name: "aragorn"},
        {timestamp: Time.zone.parse("2023-08-01 05:30:00"), value: -10, agent_name: "aragorn"},

        {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 01:30:00"), value: 1, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 02:00:00"), value: -4, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 04:00:00"), value: -2, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 05:00:00"), value: 10, agent_name: "frodo"},
        {timestamp: Time.zone.parse("2023-08-01 05:30:00"), value: -10, agent_name: "frodo"}
      ]
    end

    it "returns a grouped aggregations" do
      result = aggregator.aggregate

      expect(result.aggregations.count).to eq(2)

      result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
        expect(aggregation.aggregation.round(5).to_s).to eq("0.02218")
        expect(aggregation.count).to eq(7)
        expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
      end
    end

    context "with no events" do
      let(:events_values) { [] }

      it "returns an empty result" do
        result = aggregator.aggregate

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
        result = aggregator.aggregate

        expect(result.aggregations.count).to eq(1)

        aggregation = result.aggregations.first
        expect(aggregation.aggregation).to eq(0)
        expect(aggregation.count).to eq(0)
        expect(aggregation.grouped_by).to eq({"agent_name" => nil})
      end
    end

    context "with events with the same timestamp" do
      let(:events_values) do
        [
          {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3, agent_name: "aragorn"},

          {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 3, agent_name: "frodo"}
        ]
      end

      it "aggregates the events" do
        result = aggregator.aggregate

        expect(result.aggregations.count).to eq(2)

        result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
          expect(aggregation.aggregation.round(5)).to eq(6)
          expect(aggregation.count).to eq(2)
          expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
        end
      end
    end

    context "when billable metric is recurring" do
      let(:billable_metric) { create(:weighted_sum_billable_metric, :recurring, organization:) }

      let(:events_values) { [] }
      let(:aragorn_presentation_breakdowns) { [] }
      let(:frodo_presentation_breakdowns) { [] }

      let(:cached_aggregations) do
        [
          create(
            :cached_aggregation,
            organization:,
            charge:,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime - 1.day,
            current_aggregation: 1000,
            grouped_by: {"agent_name" => "aragorn"},
            presentation_breakdowns: aragorn_presentation_breakdowns
          ),

          create(
            :cached_aggregation,
            organization:,
            charge:,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime - 1.day,
            current_aggregation: 1000,
            grouped_by: {"agent_name" => "frodo"},
            presentation_breakdowns: frodo_presentation_breakdowns
          )
        ]
      end

      before { cached_aggregations }

      it "uses the persisted recurring value as initial value" do
        result = aggregator.aggregate

        expect(result.aggregations.count).to eq(2)

        result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
          expect(aggregation.aggregation.to_s).to eq("1000.0")
          expect(aggregation.count).to eq(0)
          expect(aggregation.variation).to eq(0)
          expect(aggregation.total_aggregated_units).to eq(1000)
          expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
          expect(aggregation.recurring_updated_at).to eq(from_datetime)
        end
      end

      context "when using presentation_by" do
        let(:presentation_by) { ["region"] }

        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-08-01 00:00:00.000"), value: 2, agent_name: "aragorn", region: "eu"},
            {timestamp: Time.zone.parse("2023-08-01 01:00:00"), value: 3, agent_name: "frodo", region: "us"}
          ]
        end

        it "returns breakdowns per presentation group within each grouped_by group" do
          result = aggregator.aggregate

          expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
            [
              {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "2.0"},
              {groups: {"agent_name" => "frodo", "region" => "us"}, value: "2.99597"}
            ]
          )
        end

        context "when frodo has cached presentation breakdowns" do
          let(:frodo_presentation_breakdowns) do
            [
              {"groups" => {"agent_name" => "frodo", "region" => "us"}, "value" => "100.0"}
            ]
          end

          it "uses frodo cached presentation breakdowns as initial values" do
            result = aggregator.aggregate

            expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
              [
                {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "2.0"},
                {groups: {"agent_name" => "frodo", "region" => "us"}, value: "102.99597"}
              ]
            )
          end
        end

        context "when aragorn has cached presentation breakdowns" do
          let(:aragorn_presentation_breakdowns) do
            [
              {"groups" => {"agent_name" => "aragorn", "region" => "eu"}, "value" => "100.0"}
            ]
          end

          it "uses aragorn cached presentation breakdowns as initial values" do
            result = aggregator.aggregate

            expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
              [
                {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "102.0"},
                {groups: {"agent_name" => "frodo", "region" => "us"}, value: "2.99597"}
              ]
            )
          end
        end
      end

      context "without cached aggregation events" do
        let(:cached_aggregations) {}

        it "returns an empty result" do
          result = aggregator.aggregate

          expect(result.aggregations.count).to eq(1)

          aggregation = result.aggregations.first
          expect(aggregation.aggregation).to eq(0)
          expect(aggregation.count).to eq(0)
          expect(aggregation.grouped_by).to eq({"agent_name" => nil})
        end

        context "with events attached to a previous subcription" do
          let(:previous_subscription) do
            create(
              :subscription,
              :terminated,
              started_at: DateTime.parse("2022-01-01 22:22:22"),
              terminated_at: DateTime.parse("2023-04-01 22:22:21")
            )
          end

          let(:customer) { previous_subscription.customer }

          let(:subscription) do
            create(
              :subscription,
              started_at: DateTime.parse("2023-04-01 22:22:22"),
              previous_subscription:,
              customer:,
              external_id: previous_subscription.external_id
            )
          end

          before do
            subscription

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              subscription: previous_subscription,
              customer:,
              timestamp: Time.zone.parse("2023-03-01 22:22:22"),
              properties: {value: 10, agent_name: "aragorn", region: "eu"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              subscription: previous_subscription,
              customer:,
              timestamp: Time.zone.parse("2023-03-01 22:22:22"),
              properties: {value: 10, agent_name: "frodo", region: "us"}
            )
          end

          it "uses previous events as latest value" do
            result = aggregator.aggregate

            expect(result.aggregations.count).to eq(2)

            result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
              expect(aggregation.aggregation.to_s).to eq("10.0")
              expect(aggregation.count).to eq(0)
              expect(aggregation.variation).to eq(0)
              expect(aggregation.total_aggregated_units).to eq(10)
              expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
              expect(aggregation.recurring_updated_at).to eq(from_datetime)
            end
          end

          context "when using presentation_by" do
            let(:presentation_by) { ["region"] }

            it "returns previous events as presentation breakdowns" do
              result = aggregator.aggregate

              expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
                [
                  {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "10.0"},
                  {groups: {"agent_name" => "frodo", "region" => "us"}, value: "10.0"}
                ]
              )
            end
          end
        end
      end

      context "with events" do
        let(:events_values) do
          [
            {timestamp: DateTime.parse("2023-08-01 00:00:00.000"), value: 2, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 01:00:00"), value: 3, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 01:30:00"), value: 1, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 02:00:00"), value: -4, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 04:00:00"), value: -2, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 05:00:00"), value: 10, agent_name: "aragorn", region: "eu"},
            {timestamp: DateTime.parse("2023-08-01 05:30:00"), value: -10, agent_name: "aragorn", region: "eu"},

            {timestamp: DateTime.parse("2023-08-01 00:00:00.000"), value: 2, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 01:00:00"), value: 3, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 01:30:00"), value: 1, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 02:00:00"), value: -4, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 04:00:00"), value: -2, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 05:00:00"), value: 10, agent_name: "frodo", region: "us"},
            {timestamp: DateTime.parse("2023-08-01 05:30:00"), value: -10, agent_name: "frodo", region: "us"}
          ]
        end

        it "aggregates the events" do
          result = aggregator.aggregate

          expect(result.aggregations.count).to eq(2)

          result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, index|
            expect(aggregation.aggregation.round(5).to_s).to eq("1000.02218")
            expect(aggregation.count).to eq(7)
            expect(aggregation.variation).to eq(0)
            expect(aggregation.total_aggregated_units).to eq(1000)
            expect(aggregation.grouped_by["agent_name"]).to eq(agent_names[index])
            expect(aggregation.recurring_updated_at).to eq("2023-08-01 05:30:00")
          end
        end

        context "when using presentation_by" do
          let(:presentation_by) { ["region"] }
          let(:aragorn_presentation_breakdowns) do
            [
              {"groups" => {"agent_name" => "aragorn", "region" => "eu"}, "value" => "100.0"}
            ]
          end
          let(:frodo_presentation_breakdowns) do
            [
              {"groups" => {"agent_name" => "frodo", "region" => "us"}, "value" => "200.0"}
            ]
          end

          it "uses cached presentation breakdowns as initial values" do
            result = aggregator.aggregate

            expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
              [
                {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "100.02218"},
                {groups: {"agent_name" => "frodo", "region" => "us"}, value: "200.02218"}
              ]
            )
          end

          context "when cached presentation breakdowns are empty" do
            let(:aragorn_presentation_breakdowns) { [] }
            let(:frodo_presentation_breakdowns) { [] }

            it "returns current events as presentation breakdowns" do
              result = aggregator.aggregate

              expect(result.breakdowns.map { |breakdown| {groups: breakdown[:groups], value: breakdown[:value].round(5).to_s} }).to match_array(
                [
                  {groups: {"agent_name" => "aragorn", "region" => "eu"}, value: "0.02218"},
                  {groups: {"agent_name" => "frodo", "region" => "us"}, value: "0.02218"}
                ]
              )
            end
          end
        end
      end
    end

    context "with filters" do
      let(:matching_filters) { {region: ["europe"]} }

      let(:events_values) do
        [
          {
            timestamp: DateTime.parse("2023-08-01 00:00:00.000"),
            value: 1000,
            region: "europe",
            agent_name: "aragorn"
          },
          {timestamp: DateTime.parse("2023-08-01 00:00:00.000"), value: 1000, region: "europe", agent_name: "frodo"}
        ]
      end

      it "aggregates the events" do
        result = aggregator.aggregate

        expect(result.aggregations.count).to eq(2)

        result.aggregations.sort_by { |a| a.grouped_by["agent_name"] }.each_with_index do |aggregation, _index|
          expect(aggregation.aggregation.round(5).to_s).to eq("1000.0")
          expect(aggregation.count).to eq(1)
        end
      end
    end
  end
end
