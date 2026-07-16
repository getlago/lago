# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillableMetrics::ProratedAggregations::UniqueCountService, transaction: false do
  subject(:unique_count_service) do
    described_class.new(
      event_store_class:,
      charge:,
      subscription:,
      boundaries: {
        from_datetime:,
        to_datetime:,
        charges_duration: 31
      },
      filters:
    )
  end

  let(:event_store_class) { Events::Stores::PostgresStore }
  let(:filters) { {event: pay_in_advance_event, grouped_by:, presentation_by:, matching_filters:, ignored_filters:} }

  let(:subscription) do
    create(
      :subscription,
      started_at:,
      subscription_at:,
      billing_time: :anniversary
    )
  end

  let(:pay_in_advance_event) { nil }
  let(:options) { {} }
  let(:subscription_at) { Time.zone.parse("2022-06-09") }
  let(:started_at) { subscription_at }
  let(:organization) { subscription.organization }
  let(:customer) { subscription.customer }
  let(:grouped_by) { nil }
  let(:presentation_by) { nil }
  let(:matching_filters) { nil }
  let(:ignored_filters) { nil }

  let(:billable_metric) do
    create(
      :billable_metric,
      organization:,
      aggregation_type: "unique_count_agg",
      field_name: "unique_id",
      recurring: true
    )
  end

  let(:charge) do
    create(
      :standard_charge,
      billable_metric:
    )
  end

  let(:from_datetime) { Time.zone.parse("2022-07-09 00:00:00 UTC") }
  let(:to_datetime) { Time.zone.parse("2022-08-08 23:59:59 UTC") }

  let(:added_at) { from_datetime - 1.month }
  let(:event) do
    create(
      :event,
      organization_id: organization.id,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      timestamp: added_at,
      properties: {unique_id: SecureRandom.uuid}
    )
  end

  before { event }

  describe "#aggregate" do
    let(:result) { unique_count_service.aggregate(options:) }

    context "with presentation group keys" do
      let(:presentation_by) { ["cloud"] }

      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: added_at,
          properties: {unique_id: "001", cloud: "aws"}
        )
      end

      let(:new_event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 10.days,
          properties: {unique_id: "002", cloud: "gcp"}
        )
      end

      before { new_event }

      it "returns the presentation breakdowns" do
        expect(result.breakdowns).to match_array([
          {groups: {"cloud" => "aws"}, value: 1},
          {groups: {"cloud" => "gcp"}, value: 1}
        ])
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }
        let(:event) { nil }

        let(:unique_count_events) do
          [
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "003", agent_name: "frodo", cloud: "aws"}
            ),
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: from_datetime + 10.days,
              properties: {unique_id: "004", agent_name: "frodo", cloud: "gcp"}
            ),
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "005", agent_name: "aragorn", cloud: "aws"}
            )
          ]
        end

        before { unique_count_events }

        it "returns the presentation breakdowns per group" do
          expect(result.breakdowns).to match_array([
            {groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 1},
            {groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 1},
            {groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 1},
            {groups: {"agent_name" => nil, "cloud" => "gcp"}, value: 1}
          ])
        end
      end
    end

    context "with persisted metric on full period" do
      it "returns the number of persisted metric" do
        expect(result.aggregation).to eq(1)
      end

      context "when there is persisted event and event added in period" do
        let(:new_event) do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 10.days,
            properties: {unique_id: SecureRandom.uuid}
          )
        end

        before { new_event }

        it "returns the correct number" do
          expect(result.aggregation).to eq((1 + 21.fdiv(31)).ceil(5))
        end
      end

      context "when subscription was terminated in the period" do
        let(:subscription) do
          create(
            :subscription,
            started_at:,
            subscription_at:,
            billing_time: :anniversary,
            terminated_at: to_datetime,
            status: :terminated
          )
        end
        let(:to_datetime) { Time.zone.parse("2022-07-24 23:59:59") }

        it "returns the prorata of the full duration" do
          expect(result.aggregation).to eq(16.fdiv(31).ceil(5))
        end
      end

      context "when subscription was upgraded in the period" do
        let(:subscription) do
          create(
            :subscription,
            started_at:,
            subscription_at:,
            billing_time: :anniversary,
            terminated_at: Time.zone.parse("2022-07-24 12:59:59"),
            status: :terminated
          )
        end
        let(:to_datetime) { Time.zone.parse("2022-07-23 23:59:59") }

        before do
          create(
            :subscription,
            previous_subscription: subscription,
            organization:,
            customer:,
            started_at: Time.zone.parse("2022-07-24 12:59:59")
          )
        end

        it "returns the prorata of the full duration" do
          expect(result.aggregation).to eq(15.fdiv(31).ceil(5))
        end
      end

      context "when subscription was started in the period" do
        let(:started_at) { Time.zone.parse("2022-08-01") }
        let(:from_datetime) { started_at }

        it "returns the prorata of the full duration" do
          expect(result.aggregation).to eq(8.fdiv(31).ceil(5))
        end
      end

      context "when filters are used" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at,
            properties: {unique_id: "111", region: "europe"}
          )
        end

        let(:matching_filters) { {region: ["europe"]} }

        it "returns the number of persisted metric" do
          expect(result.aggregation).to eq(1)
        end
      end

      context "when plan is pay in advance" do
        before do
          subscription.plan.update!(pay_in_advance: true)
        end

        it "returns the number of persisted metric" do
          expect(result.aggregation).to eq(1)
        end
      end
    end

    context "with persisted metrics added in the period" do
      let(:event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 15.days,
          properties: {unique_id: SecureRandom.uuid}
        )
      end

      it "returns the prorata of the full duration" do
        expect(result.aggregation).to eq(16.fdiv(31).ceil(5))
      end

      context "when added on the first day of the period" do
        let(:event) do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime,
            properties: {unique_id: SecureRandom.uuid}
          )
        end

        it "returns the full duration" do
          expect(result.aggregation).to eq(1)
        end
      end
    end

    context "with persisted metrics terminated in the period" do
      it "returns the prorata of the full duration" do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 15.days,
          properties: {
            unique_id: event.properties["unique_id"],
            operation_type: "remove"
          }
        )

        expect(result.aggregation).to eq(16.fdiv(31).ceil(5))
      end

      context "when removed on the last day of the period" do
        it "returns the full duration" do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: to_datetime,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "remove"
            }
          )

          expect(result.aggregation).to eq(1)
        end
      end
    end

    context "with persisted metrics added and terminated in the period" do
      let(:added_at) { from_datetime + 1.day }

      it "returns the prorata of the full duration" do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 1.day,
          properties: {
            unique_id: event.properties["unique_id"],
            operation_type: "remove"
          }
        )

        expect(result.aggregation).to eq(29.fdiv(31).ceil(5))
      end

      context "when added and removed the same day multiple times" do
        let(:added_at) { from_datetime + 1.hour }

        it "returns a 1 day duration" do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at + 1.hour,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "remove"
            }
          )

          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at + 2.hours,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "add"
            }
          )

          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at + 3.hours,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "remove"
            }
          )

          expect(result.aggregation).to eq(1.fdiv(31).ceil(5))
        end

        context "when added and removed the same day multiple days" do
          it "returns the correct number" do
            events_params = [
              {timestamp: added_at, id: event.properties["unique_id"], operation_type: "add"},
              {timestamp: added_at + 1.hour, id: event.properties["unique_id"], operation_type: "remove"},
              {timestamp: added_at + 5.days, id: event.properties["unique_id"], operation_type: "add"},
              {timestamp: added_at + 5.days + 1.hour, id: event.properties["unique_id"], operation_type: "remove"},
              {timestamp: added_at + 10.days, id: event.properties["unique_id"], operation_type: "add"},
              {timestamp: added_at + 10.days + 1.hour, id: event.properties["unique_id"], operation_type: "remove"}
            ]

            events_params.each do |event_params|
              create(
                :event,
                organization_id: organization.id,
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                timestamp: event_params[:timestamp],
                properties: {unique_id: event_params[:id], operation_type: event_params[:operation_type]}
              )
            end
            expect(result.aggregation).to eq(3.fdiv(31).ceil(5))
          end
        end
      end
    end

    context "when current usage context and charge is pay in arrear" do
      let(:options) do
        {is_pay_in_advance: false, is_current_usage: true}
      end

      it "returns correct result" do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 10.days,
          properties: {unique_id: SecureRandom.uuid}
        )

        expect(result.aggregation).to eq((1 + 21.fdiv(31)).ceil(5))
        expect(result.current_usage_units).to eq(2)
      end

      context "when added and removed several times a day during multiple days" do
        it "returns the correct result" do
          # 0 day: add (month ago - 1 day)
          # 1st day: add, add, remove, add
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 1.day,
            properties: {unique_id: event.properties["unique_id"]}
          )
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 1.day + 1.hour,
            properties: {unique_id: event.properties["unique_id"]}
          )
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 1.day + 2.hours,
            properties: {unique_id: event.properties["unique_id"], operation_type: "remove"}
          )
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 1.day + 3.hours,
            properties: {unique_id: event.properties["unique_id"]}
          )

          # 3rd day: add, remove
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 3.days + 1.hour,
            properties: {unique_id: event.properties["unique_id"]}
          )
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 3.days + 2.hours,
            properties: {unique_id: event.properties["unique_id"], operation_type: "remove"}
          )

          expect(result.aggregation).to eq(4.fdiv(31).ceil(5))
          # NOTE: current_usage_units is 0 because there are no "active" events in the period
          expect(result.current_usage_units).to eq(0)
        end
      end
    end

    context "when current usage context and charge is pay in advance" do
      let(:options) do
        {is_pay_in_advance: true, is_current_usage: true}
      end

      let(:previous_event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 5.days,
          properties: {unique_id: "000"}
        )
      end

      let(:cached_aggregation) do
        create(
          :cached_aggregation,
          organization:,
          charge:,
          event_transaction_id: previous_event.transaction_id,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 5.days,
          current_aggregation: "1",
          max_aggregation: "1",
          max_aggregation_with_proration: "0.8"
        )
      end

      before { cached_aggregation }

      it "returns period maximum as aggregation" do
        expect(result.aggregation).to eq(1.8)
        expect(result.current_usage_units).to eq(2)
      end

      context "when cached aggregation does not exist" do
        let(:cached_aggregation) { nil }

        it "returns only the past aggregation" do
          expect(result.aggregation).to eq(1)
          expect(result.current_usage_units).to eq(1)
        end
      end
    end

    context "when event is given" do
      let(:properties) { {unique_id: SecureRandom.uuid} }
      let(:pay_in_advance_event) do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 10.days,
          properties:
        )
      end

      before { pay_in_advance_event }

      it "assigns an pay_in_advance aggregation" do
        expect(result.pay_in_advance_aggregation).to eq(21.fdiv(31).ceil(5))
      end

      context "with presentation group keys" do
        let(:presentation_by) { ["cloud", "region"] }
        let(:properties) { {"unique_id" => SecureRandom.uuid, "cloud" => "aws", "region" => "eu"} }

        it "assigns pay_in_advance_breakdowns based on the pay_in_advance event" do
          expect(result.pay_in_advance_breakdowns).to eq([
            {groups: {"cloud" => "aws", "region" => "eu"}, value: 1}
          ])
        end
      end

      context "when event is missing properties" do
        let(:properties) { {} }

        it "assigns 0 as pay_in_advance aggregation" do
          expect(result.pay_in_advance_aggregation).to be_zero
        end
      end

      context "when current period aggregation is greater than period maximum" do
        let(:previous_event) do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 5.days,
            properties: {unique_id: "000"}
          )
        end

        before { previous_event }

        it "assigns a pay_in_advance aggregation" do
          expect(result.pay_in_advance_aggregation).to eq(21.fdiv(31).ceil(5))
        end
      end

      context "when current period aggregation is less than period maximum" do
        let(:previous_event) do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 5.days,
            properties: {unique_id: "000"}
          )
        end

        let(:cached_aggregation) do
          create(
            :cached_aggregation,
            organization:,
            charge:,
            event_transaction_id: previous_event.transaction_id,
            external_subscription_id: subscription.external_id,
            timestamp: previous_event.timestamp,
            current_aggregation: "4",
            max_aggregation: "7",
            max_aggregation_with_proration: "5.8"
          )
        end

        before { cached_aggregation }

        it "assigns a pay_in_advance aggregation" do
          expect(result.pay_in_advance_aggregation).to eq(0)
          expect(result.units_applied).to eq(1)
        end
      end
    end
  end

  describe "#grouped_by_aggregation" do
    let(:result) { unique_count_service.aggregate(options:) }
    let(:grouped_by) { ["agent_name"] }
    let(:agent_names) { %w[aragorn frodo] }
    let(:event) { nil }

    let(:events) do
      agent_names.each do |agent_name|
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: added_at,
          properties: {unique_id: "000", agent_name:}
        )
      end
    end

    before { events }

    context "with persisted metric on full period" do
      it "returns the number of persisted metric" do
        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.count).to eq(1)
          expect(aggregation.aggregation).to eq(1)
          expect(aggregation.full_units_number).to eq(1)
        end
      end

      context "when there is persisted event and event added in period" do
        let(:new_events) do
          agent_names.each do |agent_name|
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: from_datetime + 10.days,
              properties: {unique_id: SecureRandom.uuid, agent_name:}
            )
          end
        end

        before { new_events }

        it "returns the correct number" do
          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq((1 + 21.fdiv(31)).ceil(5))
            expect(aggregation.full_units_number).to eq(2)
          end
        end
      end

      context "when filters are used" do
        let(:events) do
          agent_names.each do |agent_name|
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "111", region: "europe", agent_name:}
            )
          end
        end

        let(:matching_filters) { {region: ["europe"]} }

        it "returns the number of persisted metric" do
          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(1)
            expect(aggregation.full_units_number).to eq(1)
          end
        end
      end
    end

    context "with persisted metrics added in the period" do
      let(:added_at) { from_datetime + 15.days }

      it "returns the prorata of the full duration" do
        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.aggregation).to eq(16.fdiv(31).ceil(5))
          expect(aggregation.full_units_number).to eq(1)
        end
      end

      context "when added on the first day of the period" do
        let(:added_at) { from_datetime }

        it "returns the full duration" do
          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(1)
            expect(aggregation.full_units_number).to eq(1)
          end
        end
      end
    end

    context "with persisted metrics terminated in the period" do
      it "returns the prorata of the full duration" do
        agent_names.each do |agent_name|
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: to_datetime - 15.days,
            properties: {unique_id: "000", region: "europe", agent_name:, operation_type: "remove"}
          )
        end

        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.aggregation).to eq(16.fdiv(31).ceil(5))
        end
      end

      context "when removed on the last day of the period" do
        it "returns the full duration" do
          agent_names.each do |agent_name|
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: to_datetime,
              properties: {unique_id: "111", region: "europe", agent_name:, operation_type: "remove"}
            )
          end

          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(1)
          end
        end
      end

      context "when added and removed the same day multiple times" do
        it "does not count the same day multiple times" do
          times_and_actions = [
            [from_datetime + 1.day, "add"],
            [from_datetime + 1.day + 1.hour, "remove"],
            [from_datetime + 1.day + 2.hours, "add"],
            [from_datetime + 1.day + 2.hours + 1.second, "remove"],
            [from_datetime + 1.day + 3.hours, "add"],
            [from_datetime + 2.days, "remove"],
            [from_datetime + 2.days + 1.hour, "add"],
            [from_datetime + 2.days + 2.hours, "remove"] # 2022-07-11
          ]
          agent_names.each do |agent_name|
            times_and_actions.each do |timestamp, action|
              create(
                :event,
                organization_id: organization.id,
                code: billable_metric.code,
                external_subscription_id: subscription.external_id,
                timestamp:,
                properties: {unique_id: "000", agent_name:, operation_type: action}
              )
            end
          end

          # aggregated by agents
          expect(result.aggregations.count).to eq(2)

          # As result of all merged events we have this table:
          # [
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-06-09T00:00:00.000Z", "operation_type" => "add", "rn" => 1, "is_ignored" => false, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-06-09T00:00:00.000Z", "operation_type" => "add", "rn" => 1, "is_ignored" => false, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-10T01:00:00.000Z", "operation_type" => "remove", "rn" => 2, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-10T01:00:00.000Z", "operation_type" => "remove", "rn" => 2, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-10T02:00:00.000Z", "operation_type" => "add", "rn" => 3, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-10T02:00:00.000Z", "operation_type" => "add", "rn" => 3, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-10T02:00:01.000Z", "operation_type" => "remove", "rn" => 4, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-10T02:00:01.000Z", "operation_type" => "remove", "rn" => 4, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-10T03:00:00.000Z", "operation_type" => "add", "rn" => 5, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-10T03:00:00.000Z", "operation_type" => "add", "rn" => 5, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-11T00:00:00.000Z", "operation_type" => "remove", "rn" => 6, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-11T00:00:00.000Z", "operation_type" => "remove", "rn" => 6, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-11T01:00:00.000Z", "operation_type" => "add", "rn" => 7, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-11T01:00:00.000Z", "operation_type" => "add", "rn" => 7, "is_ignored" => true, "previous_not_ignored_operation_type" => "add"},
          #   {"g_0" => "aragorn", "property" => "000", "timestamp" => "2022-07-11T02:00:00.000Z", "operation_type" => "remove", "rn" => 8, "is_ignored" => false, "previous_not_ignored_operation_type" => "remove"},
          #   {"g_0" => "frodo",   "property" => "000", "timestamp" => "2022-07-11T02:00:00.000Z", "operation_type" => "remove", "rn" => 8, "is_ignored" => false, "previous_not_ignored_operation_type" => "remove"}
          # ]
          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(3.fdiv(31).ceil(5)) # subscription starts on 9th, so we have 3 days of usage
          end
        end
      end
    end

    context "with persisted metrics added and terminated in the period" do
      let(:added_at) { from_datetime + 1.day }

      it "returns the prorata of the full duration" do
        agent_names.each do |agent_name|
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: to_datetime - 1.day,
            properties: {unique_id: "000", agent_name:, operation_type: "remove"}
          )
        end

        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.aggregation).to eq(29.fdiv(31).ceil(5))
        end
      end

      context "when added and removed the same day" do
        let(:added_at) { from_datetime + 1.day }

        it "returns a 1 day duration" do
          agent_names.each do |agent_name|
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at.end_of_day,
              properties: {unique_id: "000", agent_name:, operation_type: "remove"}
            )
          end

          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(1.fdiv(31).ceil(5))
          end
        end
      end
    end

    context "when current usage context and charge is pay in arrear" do
      let(:options) do
        {is_pay_in_advance: false, is_current_usage: true}
      end
      let(:new_events) do
        agent_names.map do |agent_name|
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 10.days,
            properties: {unique_id: SecureRandom.uuid, agent_name:}
          )
        end
      end

      before { new_events }

      it "returns correct result" do
        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.aggregation).to eq((1 + 21.fdiv(31)).ceil(5))
          expect(aggregation.current_usage_units).to eq(2)
        end
      end
    end

    context "when current usage context and charge is pay in advance" do
      let(:options) do
        {is_pay_in_advance: true, is_current_usage: true}
      end

      let(:previous_events) do
        agent_names.map do |agent_name|
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 5.days,
            properties: {
              unique_id: "111",
              agent_name:
            }
          )
        end
      end

      let(:cached_aggregations) do
        agent_names.map.with_index do |agent_name, index|
          create(
            :cached_aggregation,
            organization:,
            charge:,
            event_transaction_id: previous_events[index].transaction_id,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 5.days,
            current_aggregation: "1",
            max_aggregation: "1",
            max_aggregation_with_proration: "0.8",
            grouped_by: {agent_name:}
          )
        end
      end

      before { cached_aggregations }

      it "returns period maximum as aggregation" do
        expect(result.aggregations.count).to eq(2)

        result.aggregations.each do |aggregation|
          expect(aggregation.grouped_by.keys).to include("agent_name")
          expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
          expect(aggregation.aggregation).to eq(1.8)
          expect(aggregation.current_usage_units).to eq(2)
        end
      end

      context "when cached aggregation does not exist" do
        let(:cached_aggregations) { nil }

        it "returns only the past aggregation" do
          expect(result.aggregations.count).to eq(2)

          result.aggregations.each do |aggregation|
            expect(aggregation.grouped_by.keys).to include("agent_name")
            expect(aggregation.grouped_by["agent_name"]).to eq("frodo").or eq("aragorn")
            expect(aggregation.aggregation).to eq(1)
            expect(aggregation.current_usage_units).to eq(1)
            expect(aggregation.full_units_number).to eq(1)
          end
        end
      end
    end
  end

  describe ".per_event_aggregation" do
    before { unique_count_service.options = {} }

    context "with event added in the period" do
      let(:added_at) { from_datetime + 10.days }

      it "aggregates per events" do
        result = unique_count_service.per_event_aggregation

        expect(result.event_aggregation).to eq([1])
        expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([21.fdiv(31).ceil(5)])
      end

      context "with grouped_by_values" do
        before do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at,
            properties: {unique_id: SecureRandom.uuid, scheme: "visa"}
          )

          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: from_datetime + 20.days,
            properties: {unique_id: "111"}
          )
        end

        it "takes the groups into account" do
          result = unique_count_service.per_event_aggregation(grouped_by_values: {"scheme" => "visa"})

          expect(result.event_aggregation).to eq([1])
          expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([21.fdiv(31).ceil(5)])
        end

        context "when sending multiple events per day" do
          let(:event) do
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "property_1"}
            )
          end

          it "aggregates per events" do
            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "property_1", scheme: "visa"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at,
              properties: {unique_id: "property_1", scheme: "visa"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 1.hour,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "remove"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 2.hours,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "remove"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 3.hours,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "add"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 1.day,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "add"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 1.day + 1.hour,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "remove"}
            )

            create(
              :event,
              organization_id: organization.id,
              code: billable_metric.code,
              external_subscription_id: subscription.external_id,
              timestamp: added_at + 1.day + 2.hours,
              properties: {unique_id: "property_1", scheme: "visa", operation_type: "add"}
            )

            result = unique_count_service.per_event_aggregation(grouped_by_values: {"scheme" => "visa"})

            # as result of this events we have:
            # 1. timestamp: added_at, operation_type: add, property: SecureRandom.uuid, scheme: visa
            # 2. timestamp: from_datetime + 20.days, operation_type: add, property: '1111'
            # 3. timestamp: added_at, operation_type: add, property: property_1
            # 4. timestamp: added_at, operation_type: add, property: property_1, scheme: visa
            # 5. timestamp: added_at, operation_type: add, property: property_1, scheme: visa (ignored)
            # 6. timestamp: added_at + 1.hour, operation_type: remove, property: property_1, scheme: visa (ignored)
            # 7. timestamp: added_at + 2.hours, operation_type: remove, property: property_1, scheme: visa (ignored)
            # 8. timestamp: added_at + 3.hours, operation_type: add, property: property_1, scheme: visa (ignored)
            # 9. timestamp: added_at + 1.day, operation_type: add, property: property_1, scheme: visa (ignored)
            # 10. timestamp: added_at + 1.day, operation_type: remove, property: property_1, scheme: visa (ignored)
            # 11. timestamp: added_at + 1.day, operation_type: add, property: property_1, scheme: visa (ignored)
            # when grouping by scheme Visa + taking into account minimal length of proration (1 day), some events are ignored,
            # so we have 2 uniq properties: property_1, SecureRandom.uuid; '1111' doesn't have scheme visa, so it's excluded
            # length of proration is 21 days for property_1, 21 days for SecureRandom.uuid (becuase random is just added once, property_1
            # is added and removed multiple times, but the last action is add, so we merge all the events into one add)

            expect(result.event_aggregation).to eq([1, 1])
            expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([21.fdiv(31).ceil(5), 21.fdiv(31).ceil(5)])
          end
        end
      end
    end

    context "with persisted metrics removed in the period" do
      it "aggregates per events" do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 15.days,
          properties: {
            unique_id: event.properties["unique_id"],
            operation_type: "remove"
          }
        )

        result = unique_count_service.per_event_aggregation

        expect(result.event_aggregation).to eq([1, -1])
        expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([16.fdiv(31).ceil(5), 0.0])
      end

      context "when removed on the last day of the period" do
        it "aggregates per events" do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: to_datetime,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "remove"
            }
          )

          result = unique_count_service.per_event_aggregation

          expect(result.event_aggregation).to eq([1, -1])
          expect(result.event_prorated_aggregation).to eq([1, 0.0])
        end
      end
    end

    context "with persisted metrics added and removed in the period" do
      let(:added_at) { from_datetime + 1.day }

      it "aggregates per events" do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: to_datetime - 1.day,
          properties: {
            unique_id: event.properties["unique_id"],
            operation_type: "remove"
          }
        )

        result = unique_count_service.per_event_aggregation

        expect(result.event_aggregation).to eq([1, -1])
        expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([29.fdiv(31).ceil(5), 0.0])
      end

      context "when added and removed the same day" do
        let(:added_at) { from_datetime + 1.day }

        it "aggregates per events" do
          create(
            :event,
            organization_id: organization.id,
            code: billable_metric.code,
            external_subscription_id: subscription.external_id,
            timestamp: added_at.end_of_day,
            properties: {
              unique_id: event.properties["unique_id"],
              operation_type: "remove"
            }
          )

          result = unique_count_service.per_event_aggregation

          expect(result.event_aggregation).to eq([1, -1])
          expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([1.fdiv(31).ceil(5), 0.0])
        end
      end
    end

    context "with multiple events added in the period and with one added and removed during period" do
      let(:added_at) { from_datetime + 10.days }

      before do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 10.days,
          properties: {unique_id: SecureRandom.uuid}
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 20.days,
          properties: {unique_id: "111"}
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: (from_datetime + 20.days).end_of_day,
          properties: {
            unique_id: "111",
            operation_type: "remove"
          }
        )
      end

      it "aggregates per events" do
        result = unique_count_service.per_event_aggregation

        first = 21.fdiv(31).ceil(5)
        second = 1.fdiv(31).ceil(5)

        expect(result.event_aggregation).to eq([1, 1, 1, -1])
        expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([first, first, second, 0.0])
      end
    end

    context "with multiple events added and removed in the period and with one persisted" do
      before do
        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 10.days,
          properties: {unique_id: SecureRandom.uuid}
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: from_datetime + 20.days,
          properties: {unique_id: "111"}
        )

        create(
          :event,
          organization_id: organization.id,
          code: billable_metric.code,
          external_subscription_id: subscription.external_id,
          timestamp: (from_datetime + 20.days).end_of_day,
          properties: {
            unique_id: "111",
            operation_type: "remove"
          }
        )
      end

      it "aggregates per events" do
        result = unique_count_service.per_event_aggregation

        second = 21.fdiv(31).ceil(5)
        third = 1.fdiv(31).ceil(5)

        expect(result.event_aggregation).to eq([1, 1, 1, -1])
        expect(result.event_prorated_aggregation.map { |el| el.ceil(5) }).to eq([1, second, third, 0.0])
      end
    end
  end
end
