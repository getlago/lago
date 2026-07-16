# frozen_string_literal: true

RSpec.shared_examples "an event store" do |with_event_duplication: true, excluding_features: []|
  subject(:event_store) do
    described_class.new(
      code:,
      subscription:,
      boundaries:,
      filters: {
        grouped_by:,
        grouped_by_values:,
        matching_filters:,
        ignored_filters:,
        charge_id: charge&.id,
        charge_filter: charge_filter
      },
      deduplicate: with_event_duplication
    )
  end

  let(:billable_metric) { create(:billable_metric, field_name: "value", code: "bm:code") }
  let(:organization) { billable_metric.organization }
  let(:charge) { create(:standard_charge, organization:, billable_metric:) }
  let(:charge_filter) { nil }

  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, customer:, started_at:) }

  let(:started_at) { DateTime.parse("2023-03-15") }
  let(:code) { billable_metric.code }

  let(:subscription_started_at) { subscription.started_at.beginning_of_day }
  let(:boundaries) do
    {
      from_datetime: subscription_started_at,
      to_datetime: subscription.started_at.end_of_month.end_of_day,
      charges_duration: 31
    }
  end

  let(:grouped_by) { nil }
  let(:grouped_by_values) { nil }
  let(:with_grouped_by_values) { nil }
  let(:events_grouped_by) { grouped_by }
  let(:matching_filters) { {} }
  let(:ignored_filters) { [] }

  let(:events) do
    events = [
      create_event(
        timestamp: subscription_started_at + 1.day,
        value: 1,
        properties: {"region" => "europe", "country" => "france", "city" => "paris"},
        charge_filter:,
        transaction_id: SecureRandom.uuid
      ),
      create_event(
        timestamp: subscription_started_at + 2.days,
        value: 2,
        properties: {},
        transaction_id: SecureRandom.uuid
      ),
      create_event(
        timestamp: subscription_started_at + 3.days,
        value: 3,
        properties: {"region" => "europe", "country" => "france"},
        charge_filter:,
        transaction_id: SecureRandom.uuid
      ),
      create_event(
        timestamp: subscription_started_at + 4.days,
        value: 4,
        properties: {},
        transaction_id: SecureRandom.uuid
      ),
      create_event(
        timestamp: subscription_started_at + 5.days,
        value: with_event_duplication ? 10 : 5,
        properties: {"region" => "europe", "country" => "united kingdom", "city" => "london"},
        transaction_id: SecureRandom.uuid
      )
    ]

    if with_event_duplication
      last_event = events.pop

      attributes = {
        timestamp: last_event.timestamp,
        value: 5,
        properties: last_event.properties,
        transaction_id: last_event.transaction_id
      }

      if last_event.respond_to?(:charge_filter_id)
        attributes[:charge_filter] = last_event.charge_filter_id.present? ? charge_filter : nil
      end

      if last_event.respond_to?(:enriched_at)
        attributes[:enriched_at] = Time.current + 1.second
      end

      events << create_event(**attributes)
    end

    events
  end

  def grouped_prorated_to_h(results)
    results.map do |r|
      {groups: r.groups, prorated_value: r.prorated_value.to_f, value: r.value.to_f, events_count: r.events_count}
    end
  end

  def create_european_event(country:, city:, value:, timestamp:, charge_filter: nil)
    create_event(
      timestamp:,
      value:,
      properties: {"region" => "europe", "country" => country, "city" => city},
      transaction_id: SecureRandom.uuid,
      charge_filter:
    )
  end

  def create_events_for_filters
    create_european_event(country: "united kingdom", city: "manchester", value: -1, timestamp: subscription_started_at + 6.days, charge_filter:)
    create_european_event(country: "france", city: "cambridge", value: -2, timestamp: subscription_started_at + 7.days, charge_filter:)
    create_european_event(country: "france", city: "caen", value: -3, timestamp: subscription_started_at + 8.days)
    create_european_event(country: "germany", city: "berlin", value: -4, timestamp: subscription_started_at + 9.days)
    create_european_event(country: "united kingdom", city: "cambridge", value: -5, timestamp: subscription_started_at + 10.days)
  end

  define_singleton_method(:include_feature?) do |feature|
    !excluding_features.include?(feature)
  end

  before { events }

  if include_feature?(:events)
    describe "#events" do
      it "returns the events" do
        retrieved_events = event_store.events.to_a

        expect(retrieved_events.count).to eq(5)
        expect(retrieved_events).to match_array(events)
        # we need to check value because the duplicate has the same id so array equality is not sufficiant
        expect(retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }).to match_array(["1", "2", "3", "4", "5"])
      end

      context "when ordered is true" do
        it "returns the events ordered by timestamp" do
          retrieved_events = event_store.events(ordered: true)

          expect(retrieved_events).to eq(events)
          # we need to check value because the duplicate has the same id so array equality is not sufficiant
          expect(retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }).to eq(["1", "2", "3", "4", "5"])
        end
      end

      context "with events before from_datetime" do
        before do
          create_event(
            timestamp: subscription_started_at - 1.day,
            value: 0,
            properties: {"region" => "europe", "country" => "france"},
            transaction_id: SecureRandom.uuid
          )
        end

        it "excludes events before from_datetime by default" do
          retrieved_events = event_store.events.to_a
          values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

          expect(retrieved_events.count).to eq(5)
          expect(values).not_to include("0")
          expect(values).to match_array(["1", "2", "3", "4", "5"])
        end

        context "when use_from_boundary is false" do
          before { event_store.use_from_boundary = false }

          it "includes events before from_datetime" do
            retrieved_events = event_store.events.to_a
            values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

            expect(retrieved_events.count).to eq(6)
            expect(values).to match_array(["0", "1", "2", "3", "4", "5"])
          end

          context "when force_from is true" do
            it "excludes events before from_datetime" do
              retrieved_events = event_store.events(force_from: true).to_a
              values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

              expect(retrieved_events.count).to eq(5)
              expect(values).not_to include("0")
              expect(values).to match_array(["1", "2", "3", "4", "5"])
            end
          end
        end
      end

      context "with events after to_datetime" do
        let(:boundaries) do
          {
            from_datetime: subscription_started_at,
            to_datetime: subscription_started_at + 3.days + 12.hours,
            charges_duration: 31
          }
        end

        it "excludes events after to_datetime" do
          retrieved_events = event_store.events.to_a
          values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

          expect(retrieved_events.count).to eq(3)
          expect(values).to match_array(["1", "2", "3"])
        end
      end

      context "with max_timestamp boundary" do
        let(:boundaries) do
          {
            from_datetime: subscription_started_at,
            to_datetime: subscription.started_at.end_of_month.end_of_day,
            max_timestamp: subscription_started_at + 3.days + 12.hours,
            charges_duration: 31
          }
        end

        it "uses max_timestamp instead of to_datetime" do
          retrieved_events = event_store.events.to_a
          values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

          expect(retrieved_events.count).to eq(3)
          expect(values).to match_array(["1", "2", "3"])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the filtered events" do
          retrieved_events = event_store.events.to_a
          values = retrieved_events.map { |e| e.properties[billable_metric.field_name].to_s }

          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, manchester -> -1
          expect(retrieved_events.count).to eq(4)
          expect(values).to match_array(["1", "3", "-1", "-2"])
        end
      end
    end
  end

  if include_feature?(:count)
    describe "#count" do
      it "returns the number of unique events" do
        expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 5, events_count: 5))
      end

      context "with grouped_by_values" do
        let(:grouped_by_values) { {"region" => "europe"} }
        let(:events_grouped_by) { ["region"] }

        it "returns the number of unique events" do
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 3, events_count: 3))
        end

        context "when grouped_by_values value is nil" do
          let(:grouped_by_values) { {"region" => nil} }

          it "returns the number of unique events" do
            expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 2, events_count: 2))
          end
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the number of unique events" do
          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 4 events:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 4, events_count: 4))
        end

        # We faced an issue where Arel caused a Stack Level Too Deep error due to how the request `OR` conditons are build.
        # This test is used to ensure that we can handle this situation.
        # This test fails when using the Arel version.
        context "when there are many filters" do
          let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"], "city" => ["paris", "london", "cambridge", "caen", "manchester"]} }
          let(:ignored_filters) do
            Array.new(200) do |i|
              {"region" => [Faker::Alphanumeric.alphanumeric(number: 10)], "city" => [Faker::Alphanumeric.alphanumeric(number: 10)]}
            end
          end

          # This function is used to simulate a nested stack. Otherwise we'll reach the Clickhouse query size limits
          # before reaching a stack error.
          def within_nested_stack(stack_number, &block)
            if stack_number > 0
              within_nested_stack(stack_number - 1, &block)
            else
              yield
            end
          end

          it "does not raise an error" do
            within_nested_stack(8200) do
              expect do
                event_store.count
              end.not_to raise_error
            end
          end
        end

        # Charge filters with no values or duplicate values should not exist but
        # can due to missing validations. They produce empty hashes or hashes with
        # all-empty-array values in ignored_filters, which would generate invalid
        # SQL (e.g., empty Tuple() in ClickHouse) without the defensive guards.
        context "when ignored_filters contains empty and all-empty-values entries" do
          let(:ignored_filters) do
            [
              {},
              {"city" => [], "country" => []},
              {"city" => ["caen"]},
              {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}
            ]
          end

          it "returns the number of unique events ignoring empty entries" do
            expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 4, events_count: 4))
          end
        end
      end

      context "with max timestamp" do
        let(:boundaries) do
          {
            from_datetime: subscription.started_at.beginning_of_day,
            to_datetime: subscription.started_at.end_of_month.end_of_day,
            max_timestamp: subscription.started_at.beginning_of_day.end_of_day + 2.days,
            charges_duration: 31
          }
        end

        it "returns the number of unique events" do
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 2, events_count: 2))
        end
      end

      if with_event_duplication
        context "with only duplicated transaction_id" do
          before do
            event = events.first

            create_event(
              timestamp: subscription_started_at + 5.days,
              value: 1,
              properties: {},
              transaction_id: event.transaction_id
            )
          end

          it "takes the event into account" do
            expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 6, events_count: 6))
          end
        end
      end
    end
  end

  if include_feature?(:with_grouped_by_values)
    describe "#with_grouped_by_values" do
      let(:with_grouped_by_values) { {"region" => "europe"} }
      let(:events_grouped_by) { ["region"] }

      it "applies the grouped_by_values in the block" do
        event_store.with_grouped_by_values(with_grouped_by_values) do
          expect(event_store.count).to eq(Events::Stores::BaseStore::AggregationResult.new(value: 3, events_count: 3))
        end
      end
    end
  end

  if include_feature?(:grouped_count)
    describe "#grouped_count" do
      let(:grouped_by) { %w[region] }

      it "returns the number of unique events grouped by the provided group" do
        result = event_store.grouped_count

        expect(result).to match_array([
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 2, events_count: 2),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 3, events_count: 3)
        ])
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the number of unique events grouped by the provided groups" do
          result = event_store.grouped_count

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 2, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => nil, "region" => nil}, value: 2, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: 1, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:sum_precise_total_amount_cents)
    describe "#sum_precise_total_amount_cents" do
      it "returns the sum of precise_total_amount_cent values" do
        expect(event_store.sum_precise_total_amount_cents).to eq(15)
      end

      context "without events" do
        let(:events) { [] }

        it "returns zero" do
          expect(event_store.sum_precise_total_amount_cents).to eq(0)
        end
      end
    end
  end

  if include_feature?(:grouped_sum_precise_total_amount_cents)
    describe "#grouped_sum_precise_total_amount_cents" do
      let(:grouped_by) { %w[region] }

      it "returns the sum of values grouped by the provided group" do
        result = event_store.grouped_sum_precise_total_amount_cents

        expect(result).to match_array([{groups: {"region" => nil}, value: 6}, {groups: {"region" => "europe"}, value: 9}])
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the sum of values grouped by the provided groups" do
          result = event_store.grouped_sum_precise_total_amount_cents

          expect(result).to match_array([
            {groups: {"country" => "united kingdom", "region" => "europe"}, value: 5},
            {groups: {"country" => nil, "region" => nil}, value: 6},
            {groups: {"country" => "france", "region" => "europe"}, value: 4}
          ])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:grouped_by) { %w[region country] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the sum filtered and grouped" do
          result = event_store.grouped_sum_precise_total_amount_cents

          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 2 events:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, manchester -> -1
          expect(result).to match_array([
            {groups: {"country" => "united kingdom", "region" => "europe"}, value: -1},
            {groups: {"country" => "france", "region" => "europe"}, value: 2}
          ])
        end
      end
    end
  end

  if include_feature?(:active_unique_property?)
    describe "#active_unique_property?" do
      before { event_store.aggregation_property = billable_metric.field_name }

      it "returns false when no previous events exist" do
        event = create_event(timestamp: subscription_started_at + 2.days, value: 999)
        expect(event_store).not_to be_active_unique_property(event)
      end

      context "when event is already active" do
        it "returns true if the event property is active" do
          event = create_event(timestamp: subscription_started_at + 3.days, value: 2)

          expect(event_store).to be_active_unique_property(event)
        end
      end

      context "with a previous removed event" do
        before do
          create_event(timestamp: subscription_started_at + 2.days + 1.hour, value: 2, properties: {operation_type: "remove"})
        end

        it "returns false" do
          event = create_event(timestamp: subscription_started_at + 3.days, value: 2)

          expect(event_store).not_to be_active_unique_property(event)
        end
      end
    end
  end

  if include_feature?(:unique_count)
    describe "#unique_count" do
      it "returns the number of unique active event properties" do
        create_event(timestamp: subscription_started_at + 2.days + 1.hour, value: 2, properties: {operation_type: "remove"})

        event_store.aggregation_property = billable_metric.field_name

        result = event_store.unique_count

        expect(result.value).to eq(4) # 5 events added / 1 removed
        expect(result.events_count).to eq(4)
      end
    end
  end

  if include_feature?(:prorated_unique_count)
    describe "#prorated_unique_count" do
      before do
        event_store.aggregation_property = billable_metric.field_name
      end

      it "returns the number of unique active event properties" do
        create_event(
          timestamp: boundaries[:from_datetime] + 0.days,
          value: "2"
        )

        create_event(
          timestamp: (boundaries[:from_datetime] + 0.days).end_of_day,
          properties: {
            operation_type: "remove"
          },
          value: "2"
        )

        # NOTE: Events calculation: 16/31 + 1/31 + 15/31 + 14/31 + 13/31 + 12/31
        # Events:
        # 1 => added on 0 day, never removed => 16/31
        # 2 => added on 0 day, removed on 0 day => 1/31
        # 2 => added on 1 day, never removed => 15/31
        # 3 => added on 2 day, never removed => 14/31
        # 4 => added on 3 day, never removed => 13/31
        # 5 => added on 4 day, never removed => 12/31
        expect(event_store.prorated_unique_count.value.round(3)).to eq(2.29)
      end

      context "with multiple events at the same day" do
        it "returns the number of unique active event properties merged within one day" do
          event_params = [
            {timestamp: boundaries[:from_datetime], operation_type: "remove"},
            {timestamp: boundaries[:from_datetime] + 1.hour, operation_type: "add"},
            {timestamp: boundaries[:from_datetime] + 2.hours, operation_type: "remove"},
            {timestamp: boundaries[:from_datetime] + 3.hours, operation_type: "add"},
            {timestamp: boundaries[:from_datetime] + 1.day, operation_type: "remove"},
            {timestamp: boundaries[:from_datetime] + 1.day + 1.hour, operation_type: "add"},
            {timestamp: boundaries[:from_datetime] + 2.days + 1.hour, operation_type: "remove"}
          ]

          event_params.each do |params|
            create_event(
              timestamp: params[:timestamp],
              properties: {
                operation_type: params[:operation_type]
              },
              value: "2"
            )
          end

          # NOTE: Events calculation: 3/31
          # Events:
          # 1 => added on 0 day, never removed => 16/31
          # 2 => added on 0 day, removed on 2 day => 3/31
          # 3 => added on 2 day, never removed => 14/31
          # 4 => added on 3 day, never removed => 13/31
          # 5 => added on 4 day, never removed => 12/31
          expect(event_store.prorated_unique_count.value.round(3)).to eq(1.871) # 16/31 + 3/31 + 14/31 + 13/31 + 12/31
        end
      end
    end
  end

  if include_feature?(:prorated_unique_count_breakdown)
    describe "#prorated_unique_count_breakdown" do
      before do
        event_store.aggregation_property = billable_metric.field_name
      end

      it "returns the breakdown of add and remove of unique event properties" do
        create_event(
          timestamp: boundaries[:from_datetime] + 1.day,
          value: "2"
        )

        create_event(
          timestamp: boundaries[:from_datetime] + 1.day,
          value: "30"
        )

        create_event(
          timestamp: (boundaries[:from_datetime] + 1.day).end_of_day,
          properties: {
            operation_type: "remove"
          },
          value: "2"
        )

        result = event_store.prorated_unique_count_breakdown
        expect(result.count).to eq(7)

        # Ensure consistent ordering with 2 events with the same timestamp
        expect(result.map { it["property"] }).to eq(%w[1 2 30 2 3 4 5])

        grouped_result = result.group_by { |r| r["property"] }

        # NOTE: group with property 1
        group = grouped_result["1"]
        expect(group.count).to eq(1)
        expect(group.first["prorated_value"].round(3)).to eq(0.516) # 16/31
        expect(group.first["operation_type"]).to eq("add")

        # NOTE: group with property 2 (added and removed)
        group = grouped_result["2"]
        expect(group.first["prorated_value"].round(3)).to eq(0.032) # 1/31
        expect(group.last["prorated_value"].round(3)).to eq(0.484) # 15/31
        expect(group.count).to eq(2)

        # NOTE: group with property 3
        group = grouped_result["3"]
        expect(group.count).to eq(1)
        expect(group.first["prorated_value"].round(3)).to eq(0.452) # 14/31
        expect(group.first["operation_type"]).to eq("add")

        # NOTE: group with property 4
        group = grouped_result["4"]
        expect(group.count).to eq(1)
        expect(group.first["prorated_value"].round(3)).to eq(0.419) # 13/31
        expect(group.first["operation_type"]).to eq("add")

        # NOTE: group with property 5
        group = grouped_result["5"]
        expect(group.count).to eq(1)
        expect(group.first["prorated_value"].round(3)).to eq(0.387) # 12/31
        expect(group.first["operation_type"]).to eq("add")
      end
    end
  end

  if include_feature?(:grouped_unique_count)
    describe "#grouped_unique_count" do
      let(:grouped_by) { %w[region country city] }
      let(:started_at) { Time.zone.parse("2023-03-01") }

      before do
        event_store.aggregation_property = billable_metric.field_name
      end

      it "returns the unique count of event properties" do
        result = event_store.grouped_unique_count

        expect(result).to match_array([
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"city" => nil, "country" => "france", "region" => "europe"}, value: 1, events_count: 1),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"city" => "paris", "country" => "france", "region" => "europe"}, value: 1, events_count: 1),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"city" => "london", "country" => "united kingdom", "region" => "europe"}, value: 1, events_count: 1),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"city" => nil, "country" => nil, "region" => nil}, value: 2, events_count: 2)
        ])
      end

      context "with no events" do
        let(:events) { [] }

        it "returns the unique count of event properties" do
          result = event_store.grouped_unique_count
          expect(result.count).to eq(0)
        end
      end
    end
  end

  if include_feature?(:grouped_prorated_unique_count)
    describe "#grouped_prorated_unique_count" do
      let(:grouped_by) { %w[agent_name other] }
      let(:events_grouped_by) { ["agent_name", "other"] }
      let(:started_at) { Time.zone.parse("2023-03-01") }

      let(:events) do
        [
          create_event(
            timestamp: boundaries[:from_datetime] + 1.day,
            properties: {
              "agent_name" => "frodo"
            },
            value: "2"
          ),
          create_event(
            timestamp: boundaries[:from_datetime] + 1.day,
            properties: {
              "agent_name" => "aragorn"
            },
            value: "2"
          ),
          create_event(
            timestamp: (boundaries[:from_datetime] + 1.day).end_of_day,
            properties: {
              "agent_name" => "aragorn",
              "operation_type" => "remove"
            },
            value: "2"
          ),
          create_event(
            timestamp: boundaries[:from_datetime] + 2.days,
            value: "2"
          )
        ]
      end

      before do
        event_store.aggregation_property = billable_metric.field_name
      end

      it "returns the unique count of event properties" do
        result = event_store.grouped_prorated_unique_count

        expect(result.count).to eq(3)

        null_group = result.find { |v| v.groups["agent_name"].nil? }
        expect(null_group.groups["other"]).to be_nil
        expect(null_group.value.round(3)).to eq(0.935) # 29/31

        # NOTE: Events calculation: [1/31, 30/31]
        expect((result - [null_group]).map { |r| r.value.round(3) }).to contain_exactly(0.032, 0.968)
      end

      context "with no events" do
        let(:events) { [] }

        it "returns the unique count of event properties" do
          result = event_store.grouped_prorated_unique_count
          expect(result.count).to eq(0)
        end
      end
    end
  end

  if include_feature?(:events_values)
    describe "#events_values" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the value attached to each event" do
        expect(event_store.events_values).to eq([1, 2, 3, 4, 5])
      end

      context "with limit" do
        it "returns the value attached to each event" do
          expect(event_store.events_values(limit: 2)).to eq([1, 2])
        end
      end

      context "when exclude_event is true" do
        subject(:event_store) do
          described_class.new(
            code:,
            subscription:,
            boundaries:,
            filters: {
              grouped_by:,
              grouped_by_values:,
              matching_filters:,
              ignored_filters:,
              event:,
              charge_id: charge&.id,
              charge_filter: charge_filter
            },
            deduplicate: with_event_duplication
          )
        end

        let(:event) do
          create_event(timestamp: subscription_started_at + 1.day, value: 6)
        end

        it "excludes current event but returns the value attached to other events" do
          event

          expect(event_store.events_values(exclude_event: true)).to eq([1, 2, 3, 4, 5])
        end
      end

      context "with events before from_datetime" do
        before do
          create_event(
            timestamp: subscription_started_at - 1.day,
            value: 0,
            properties: {"region" => "europe", "country" => "france"},
            transaction_id: SecureRandom.uuid
          )
        end

        it "excludes values from events before from_datetime by default" do
          expect(event_store.events_values).to eq([1, 2, 3, 4, 5])
        end

        context "when use_from_boundary is false" do
          before { event_store.use_from_boundary = false }

          it "includes values from events before from_datetime" do
            expect(event_store.events_values).to eq([0, 1, 2, 3, 4, 5])
          end

          context "when force_from is true" do
            it "excludes values from events before from_datetime" do
              expect(event_store.events_values(force_from: true)).to eq([1, 2, 3, 4, 5])
            end
          end
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the filtered event values" do
          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, manchester -> -1
          expect(event_store.events_values).to eq([1, 3, -1, -2])
        end
      end
    end
  end

  if include_feature?(:last_event)
    describe "#last_event" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the last event" do
        expect(event_store.last_event.transaction_id).to eq(events.last.transaction_id)
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the last filtered event" do
          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, paris -> 1 (day +1)
          # - europe, france, <nil> -> 3 (day +3)
          # - europe, united kingdom, manchester -> -1 (day +6)
          # - europe, france, cambridge -> -2 (day +7)
          # Last event is france, cambridge with value -2
          expect(event_store.last_event.properties[billable_metric.field_name].to_i).to eq(-2)
        end
      end
    end
  end

  if include_feature?(:grouped_last_event)
    describe "#grouped_last_event" do
      let(:grouped_by) { %w[region] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the last events grouped by the provided group" do
        result = event_store.grouped_last_event

        expect(result).to match_array([
          {groups: {"region" => nil}, timestamp: format_timestamp("2023-03-19 00:00:00.000"), value: 4},
          {groups: {"region" => "europe"}, timestamp: format_timestamp("2023-03-20 00:00:00.000"), value: 5}
        ])
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the last events grouped by the provided groups" do
          result = event_store.grouped_last_event

          expect(result).to match_array([
            {groups: {"country" => "france", "region" => "europe"}, timestamp: format_timestamp("2023-03-18 00:00:00.000"), value: 3},
            {groups: {"country" => nil, "region" => nil}, timestamp: format_timestamp("2023-03-19 00:00:00.000"), value: 4},
            {groups: {"country" => "united kingdom", "region" => "europe"}, timestamp: format_timestamp("2023-03-20 00:00:00.000"), value: 5}
          ])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:grouped_by) { %w[region country] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the last events filtered and grouped" do
          result = event_store.grouped_last_event

          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 4 events:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          # We keep last event for each group:
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          expect(result).to match_array(
            [
              {
                groups: {"country" => "france", "region" => "europe"},
                timestamp: format_timestamp("2023-03-22T00:00:00.000Z"),
                value: -2
              },
              {
                groups: {"country" => "united kingdom", "region" => "europe"},
                timestamp: format_timestamp("2023-03-21T00:00:00.000Z"),
                value: -1
              }
            ]
          )
        end
      end
    end
  end

  if include_feature?(:max)
    describe "#max" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the max value" do
        result = event_store.max

        expect(result.value).to eq(5)
        expect(result.events_count).to eq(5)
      end

      context "with grouped_by_values" do
        let(:grouped_by_values) { {"region" => "europe"} }
        let(:events_grouped_by) { ["region"] }

        it "returns the max value" do
          result = event_store.max

          expect(result.value).to eq(5)
          expect(result.events_count).to eq(3)
        end

        context "when grouped_by_values value is nil" do
          let(:grouped_by_values) { {"region" => nil} }

          it "returns the max value" do
            result = event_store.max

            expect(result.value).to eq(4)
            expect(result.events_count).to eq(2)
          end
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the max value filtered" do
          result = event_store.max

          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, manchester -> -1
          # Max value is 3
          expect(result.value).to eq(3)
          expect(result.events_count).to eq(4)
        end
      end

      context "when with_count is set to false" do
        it "does not include events_count in the result" do
          result = event_store.max(with_count: false)

          expect(result.value).to eq(5)
          expect(result.events_count).to be_nil
        end
      end
    end
  end

  if include_feature?(:grouped_max)
    describe "#grouped_max" do
      let(:grouped_by) { %w[region] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the max values and the events count grouped by the provided group" do
        result = event_store.grouped_max

        expect(result).to match_array([
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 4, events_count: 2),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 5, events_count: 3)
        ])
      end

      context "when with_count is false" do
        it "returns the max values without the events count" do
          result = event_store.grouped_max(with_count: false)

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 4, events_count: nil),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 5, events_count: nil)
          ])
        end
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the max values grouped by the provided groups" do
          result = event_store.grouped_max

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 3, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => nil, "region" => nil}, value: 4, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: 5, events_count: 1)
          ])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:grouped_by) { %w[region country] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the max events filtered and grouped" do
          result = event_store.grouped_max

          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 2 events:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          # We keep "max" event for each group:
          # - europe, france, <nil>
          # - europe, united kingdom, manchester
          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: -1, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 3, events_count: 3)
          ])
        end
      end
    end
  end

  if include_feature?(:last)
    describe "#last" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the last event value and the events count" do
        result = event_store.last

        expect(result.value).to eq(5)
        expect(result.events_count).to eq(5)
      end

      context "when with_count is false" do
        it "does not include events_count in the result" do
          result = event_store.last(with_count: false)

          expect(result.value).to eq(5)
          expect(result.events_count).to be_nil
        end
      end

      context "when there's no events" do
        let(:events) { [] }

        it "returns a nil value and a zero count" do
          result = event_store.last

          expect(result.value).to be_nil
          expect(result.events_count).to eq(0)
        end
      end

      context "when the last event does not have a value" do
        let(:events) do
          [create_event(timestamp: subscription_started_at + 1.day, value: nil)]
        end

        it "returns a nil value" do
          # NOTE: events_count is intentionally not asserted here: Postgres filters
          #       out events missing the aggregation property while Clickhouse keeps
          #       them, so the count of a no-value event differs between stores.
          result = event_store.last

          expect(result.value).to be_nil
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the last filtered event value" do
          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, paris -> 1 (day +1)
          # - europe, france, <nil> -> 3 (day +3)
          # - europe, united kingdom, manchester -> -1 (day +6)
          # - europe, france, cambridge -> -2 (day +7)
          # Last value is -2
          result = event_store.last

          expect(result.value).to eq(-2)
          expect(result.events_count).to eq(4)
        end
      end
    end
  end

  if include_feature?(:grouped_last)
    describe "#grouped_last" do
      let(:grouped_by) { %w[region] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the last value and the events count for each group" do
        result = event_store.grouped_last

        expect(result).to match_array([
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 4, events_count: 2),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 5, events_count: 3)
        ])
      end

      context "when with_count is false" do
        it "returns the last value without the events count" do
          result = event_store.grouped_last(with_count: false)

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 4, events_count: nil),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 5, events_count: nil)
          ])
        end
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the last value for each provided groups" do
          result = event_store.grouped_last

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => nil, "region" => nil}, value: 4, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 3, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: 5, events_count: 1)
          ])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:grouped_by) { %w[region country] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the last values filtered and grouped" do
          result = event_store.grouped_last

          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 2 events:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          # We keep last event for each group:
          # - europe, france, cambridge
          # - europe, united kingdom, manchester
          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: -1, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: -2, events_count: 3)
          ])
        end
      end
    end
  end

  if include_feature?(:sum)
    describe "#sum" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the sum of event properties" do
        result = event_store.sum

        expect(result.value).to eq(15)
        expect(result.events_count).to eq(5)
      end

      if with_event_duplication
        context "with only duplicated transaction_id" do
          before do
            event = events.first

            create_event(timestamp: subscription_started_at + 5.days, value: 100, transaction_id: event.transaction_id)
          end

          it "takes the event into account" do
            result = event_store.sum

            expect(result.value).to eq(115) # New event value added to the previous one
            expect(result.events_count).to eq(6)
          end
        end
      end

      context "when with_count is set to false" do
        it "does not include events_count in the result" do
          result = event_store.sum(with_count: false)

          expect(result.value).to eq(15)
          expect(result.events_count).to be_nil
        end
      end

      context "with events before from_datetime" do
        before do
          create_event(
            timestamp: subscription_started_at - 1.day,
            value: 100,
            properties: {"region" => "europe", "country" => "france"},
            transaction_id: SecureRandom.uuid
          )
        end

        it "excludes events before from_datetime by default" do
          result = event_store.sum

          expect(result.value).to eq(15)
          expect(result.events_count).to eq(5)
        end

        context "when use_from_boundary is false" do
          before { event_store.use_from_boundary = false }

          it "includes events before from_datetime" do
            result = event_store.sum

            expect(result.value).to eq(115)
            expect(result.events_count).to eq(6)
          end

          context "when force_from is true" do
            it "excludes events before from_datetime" do
              # Note: #sum doesn't use force_from directly, it goes through events_cte_queries
              # which respects use_from_boundary. This test verifies the boundary is applied.
              event_store.use_from_boundary = true

              result = event_store.sum

              expect(result.value).to eq(15)
              expect(result.events_count).to eq(5)
            end
          end
        end
      end

      context "with events after to_datetime" do
        let(:boundaries) do
          {
            from_datetime: subscription_started_at,
            to_datetime: subscription_started_at + 3.days + 12.hours,
            charges_duration: 31
          }
        end

        it "excludes events after to_datetime" do
          result = event_store.sum

          # Only events with values 1, 2, 3 are within the boundary
          expect(result.value).to eq(6)
          expect(result.events_count).to eq(3)
        end
      end

      context "with max_timestamp boundary" do
        let(:boundaries) do
          {
            from_datetime: subscription_started_at,
            to_datetime: subscription.started_at.end_of_month.end_of_day,
            max_timestamp: subscription_started_at + 3.days + 12.hours,
            charges_duration: 31
          }
        end

        it "uses max_timestamp instead of to_datetime" do
          result = event_store.sum

          # Only events with values 1, 2, 3 are within the boundary
          expect(result.value).to eq(6)
          expect(result.events_count).to eq(3)
        end
      end
    end
  end

  if include_feature?(:grouped_sum)
    describe "#grouped_sum" do
      let(:grouped_by) { %w[region] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the sum of values grouped by the provided group" do
        result = event_store.grouped_sum

        expect(result).to match_array([
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 6, events_count: 2),
          Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 9, events_count: 3)
        ])
      end

      context "when with_count is false" do
        it "returns the sum of values without the events count" do
          result = event_store.grouped_sum(with_count: false)

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => nil}, value: 6, events_count: nil),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"region" => "europe"}, value: 9, events_count: nil)
          ])
        end
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the sum of values grouped by the provided groups" do
          result = event_store.grouped_sum

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => nil, "region" => nil}, value: 6, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: 5, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 4, events_count: 2)
          ])
        end
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }
        let(:grouped_by) { %w[region country] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the sum filtered and grouped" do
          result = event_store.grouped_sum

          # We include:
          # - europe, france, <nil>
          # - europe, france, paris
          # - europe, france, caen
          # - europe, france, cambridge
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # - europe, united kingdom, manchester
          # Then exclude:
          # - europe, france, caen
          # - europe, united kingdom, cambridge
          # - europe, united kingdom, london
          # We should have 2 events:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, manchester -> -1
          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "united kingdom", "region" => "europe"}, value: -1, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"country" => "france", "region" => "europe"}, value: 2, events_count: 3)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_sum_breakdown)
    describe "#grouped_sum with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      context "without grouped_by" do
        before do
          3.times { create_event(timestamp: subscription_started_at + 1.day, value: 10, properties: {"cloud" => "aws"}) }
          create_event(timestamp: subscription_started_at + 1.day, value: 12, properties: {"cloud" => "gcp"})
        end

        it "returns the sum breakdown by presentation_by" do
          result = event_store.grouped_sum(["cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "aws"}, value: 30, events_count: 3),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "gcp"}, value: 12, events_count: 1)
          ])
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 1.day, value: 7, properties: {"agent_name" => "frodo", "cloud" => "gcp"})
          create_event(timestamp: subscription_started_at + 1.day, value: 3, properties: {"agent_name" => "aragorn", "cloud" => "aws"})
        end

        it "returns the sum breakdown per group" do
          result = event_store.grouped_sum(["agent_name", "cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 7, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 3, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_count_breakdown)
    describe "#grouped_count with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }

      context "without grouped_by" do
        before do
          3.times { create_event(timestamp: subscription_started_at + 1.day, value: 10, properties: {"cloud" => "aws"}) }
          create_event(timestamp: subscription_started_at + 1.day, value: 12, properties: {"cloud" => "gcp"})
        end

        it "returns the count breakdown by presentation_by" do
          result = event_store.grouped_count(["cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "aws"}, value: 3, events_count: 3),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "gcp"}, value: 1, events_count: 1)
          ])
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          2.times { create_event(timestamp: subscription_started_at + 1.day, value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"}) }
          create_event(timestamp: subscription_started_at + 1.day, value: 7, properties: {"agent_name" => "frodo", "cloud" => "gcp"})
          create_event(timestamp: subscription_started_at + 1.day, value: 3, properties: {"agent_name" => "aragorn", "cloud" => "aws"})
        end

        it "returns the count breakdown per group" do
          result = event_store.grouped_count(["agent_name", "cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 1, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 1, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_last_breakdown)
    describe "#grouped_last with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      context "without grouped_by" do
        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 10, properties: {"cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 2.days, value: 12, properties: {"cloud" => "gcp"})
        end

        it "returns the latest value per cloud" do
          result = event_store.grouped_last(["cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "gcp"}, value: 12, events_count: 2)
          ])
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 2.days, value: 7, properties: {"agent_name" => "frodo", "cloud" => "gcp"})
          create_event(timestamp: subscription_started_at + 1.day + 1.second, value: 3, properties: {"agent_name" => "aragorn", "cloud" => "aws"})
        end

        it "returns the latest value per group and cloud" do
          result = event_store.grouped_last(["agent_name", "cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 7, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 3, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_max_breakdown)
    describe "#grouped_max with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      context "without grouped_by" do
        before do
          3.times { create_event(timestamp: subscription_started_at + 1.day, value: 10, properties: {"cloud" => "aws"}) }
          create_event(timestamp: subscription_started_at + 1.day, value: 12, properties: {"cloud" => "gcp"})
        end

        it "returns the max value per cloud" do
          result = event_store.grouped_max(["cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "aws"}, value: 10, events_count: 3),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "gcp"}, value: 12, events_count: 1)
          ])
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 1.day, value: 7, properties: {"agent_name" => "frodo", "cloud" => "gcp"})
          create_event(timestamp: subscription_started_at + 1.day, value: 3, properties: {"agent_name" => "aragorn", "cloud" => "aws"})
        end

        it "returns the max value per group and cloud" do
          result = event_store.grouped_max(["agent_name", "cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 7, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 3, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_unique_count_breakdown)
    describe "#grouped_unique_count with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }

      before do
        event_store.aggregation_property = billable_metric.field_name
      end

      context "without grouped_by" do
        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 2.days, value: 2, properties: {"cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 3.days, value: 3, properties: {"cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"cloud" => "gcp"})
        end

        it "returns the unique count breakdown by presentation_by" do
          result = event_store.grouped_unique_count(["cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "aws"}, value: 3, events_count: 3),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"cloud" => "gcp"}, value: 1, events_count: 1)
          ])
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 2.days, value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"agent_name" => "frodo", "cloud" => "gcp"})
          create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"agent_name" => "aragorn", "cloud" => "aws"})
        end

        it "returns the unique count breakdown per group" do
          result = event_store.grouped_unique_count(["agent_name", "cloud"])

          expect(result).to match_array([
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "aws"}, value: 2, events_count: 2),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "frodo", "cloud" => "gcp"}, value: 1, events_count: 1),
            Events::Stores::BaseStore::GroupedAggregationResult.new(groups: {"agent_name" => "aragorn", "cloud" => "aws"}, value: 1, events_count: 1)
          ])
        end
      end
    end
  end

  if include_feature?(:grouped_weighted_sum_breakdown)
    describe "#grouped_weighted_sum with breakdown columns" do
      subject(:event_store) do
        described_class.new(
          code:,
          subscription:,
          boundaries:,
          filters: {
            grouped_by:,
            grouped_by_values:,
            presentation_by: ["cloud"],
            matching_filters:,
            ignored_filters:,
            charge_id: charge&.id,
            charge_filter: charge_filter
          },
          deduplicate: with_event_duplication
        )
      end

      let(:events) { [] }
      let(:started_at) { Time.zone.parse("2023-03-01") }

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      context "without grouped_by" do
        before do
          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"cloud" => "aws"})

          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"cloud" => "gcp"})
        end

        it "returns the weighted sum breakdown by presentation_by" do
          result = event_store.grouped_weighted_sum(["cloud"])

          expect(result.size).to eq(2)
          expect(result.map { |r| r.groups }).to match_array([{"cloud" => "aws"}, {"cloud" => "gcp"}])
          result.each { |r| expect(r.value.round(5)).to eq(0.02218) }
        end
      end

      context "with grouped_by" do
        let(:grouped_by) { ["agent_name"] }

        before do
          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"agent_name" => "frodo", "cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"agent_name" => "frodo", "cloud" => "aws"})

          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"agent_name" => "aragorn", "cloud" => "gcp"})
        end

        it "returns the weighted sum breakdown per group" do
          result = event_store.grouped_weighted_sum(["agent_name", "cloud"])

          expect(result.map { |r| r.groups }).to match_array([
            {"agent_name" => "frodo", "cloud" => "aws"},
            {"agent_name" => "aragorn", "cloud" => "gcp"}
          ])
          result.each { |r| expect(r.value.round(5)).to eq(0.02218) }
        end
      end

      context "with no events" do
        it "returns an empty array" do
          result = event_store.grouped_weighted_sum(["cloud"])

          expect(result).to eq([])
        end
      end

      context "with initial values" do
        let(:initial_values) do
          [
            {groups: {"cloud" => "aws"}, value: 1000},
            {groups: {"cloud" => "gcp"}, value: 1000}
          ]
        end

        before do
          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"cloud" => "aws"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"cloud" => "aws"})

          create_event(timestamp: Time.zone.parse("2023-03-05 00:00:00"), value: 2, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, properties: {"cloud" => "gcp"})
          create_event(timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, properties: {"cloud" => "gcp"})
        end

        it "uses the initial values in the aggregation" do
          result = event_store.grouped_weighted_sum(["cloud"], initial_values:)

          expect(result.map { |r| r.groups }).to match_array([{"cloud" => "aws"}, {"cloud" => "gcp"}])
          result.each { |r| expect(r.value.round(5)).to eq(1000.02218) }
        end
      end
    end
  end

  if include_feature?(:sum_date_breakdown)
    describe "#sum_date_breakdown" do
      it "returns the sum grouped by day" do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        expect(event_store.sum_date_breakdown).to eq(
          events.map do |e|
            {
              date: e.timestamp.to_date,
              value: e.properties[billable_metric.field_name].to_i
            }
          end
        )
      end
    end
  end

  if include_feature?(:prorated_events_values)
    describe "#prorated_events_values" do
      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the values attached to each event with prorata on period duration" do
        expect(event_store.prorated_events_values(31).map { |v| v.round(3) }).to eq(
          [0.516, 0.968, 1.355, 1.677, 1.935]
        )
      end

      context "with filters" do
        let(:matching_filters) { {"region" => ["europe"], "country" => ["france", "united kingdom"]} }
        let(:ignored_filters) { [{"city" => ["caen"]}, {"city" => ["cambridge", "london"], "country" => ["united kingdom"]}] }

        let(:charge_filter) { create(:charge_filter, charge:) }

        before { create_events_for_filters }

        it "returns the filtered prorated event values" do
          # We include:
          # - europe, france, <nil> -> 3
          # - europe, france, paris -> 1
          # - europe, france, caen -> -3
          # - europe, france, cambridge -> -2
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # - europe, united kingdom, manchester -> -1
          # Then exclude:
          # - europe, france, caen -> -3
          # - europe, united kingdom, cambridge -> -5
          # - europe, united kingdom, london -> 5
          # We should have 4 events:
          # - europe, france, paris -> 1 (day +1) -> 1 * 16/31 ≈ 0.516
          # - europe, france, <nil> -> 3 (day +3) -> 3 * 14/31 ≈ 1.355
          # - europe, united kingdom, manchester -> -1 (day +6) -> -1 * 11/31 ≈ -0.355
          # - europe, france, cambridge -> -2 (day +7) -> -2 * 10/31 ≈ -0.645
          expect(event_store.prorated_events_values(31).map { |v| v.round(3) }).to eq(
            [0.516, 1.355, -0.355, -0.645]
          )
        end
      end
    end
  end

  if include_feature?(:prorated_sum)
    describe "#prorated_sum" do
      it "returns the prorated sum alongside the non-prorated value and events count" do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        result = event_store.prorated_sum(period_duration: 31)

        expect(result.prorated_value.round(5)).to eq(6.45161)
        expect(result.value.to_f).to eq(15)
        expect(result.events_count).to eq(5)
      end

      context "with persisted_duration" do
        it "returns the prorated sum alongside the non-prorated value and events count" do
          event_store.aggregation_property = billable_metric.field_name
          event_store.numeric_property = true

          result = event_store.prorated_sum(period_duration: 31, persisted_duration: 10)

          expect(result.prorated_value.round(5)).to eq(4.83871)
          expect(result.value.to_f).to eq(15)
          expect(result.events_count).to eq(5)
        end
      end
    end
  end

  if include_feature?(:grouped_prorated_sum)
    describe "#grouped_prorated_sum" do
      let(:grouped_by) { %w[region] }

      it "returns the prorated sum alongside the non-prorated value and events count" do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        result = event_store.grouped_prorated_sum(period_duration: 31)

        expect(grouped_prorated_to_h(result)).to match_array([
          {groups: {"region" => nil}, prorated_value: within(0.00001).of(2.64516), value: 6, events_count: 2},
          {groups: {"region" => "europe"}, prorated_value: within(0.00001).of(3.80645), value: 9, events_count: 3}
        ])
      end

      context "with persisted_duration" do
        it "returns the prorated sum alongside the non-prorated value and events count" do
          event_store.aggregation_property = billable_metric.field_name
          event_store.numeric_property = true

          result = event_store.grouped_prorated_sum(period_duration: 31, persisted_duration: 10)

          expect(grouped_prorated_to_h(result)).to match_array([
            {groups: {"region" => nil}, prorated_value: within(0.00001).of(1.93548), value: 6, events_count: 2},
            {groups: {"region" => "europe"}, prorated_value: within(0.00001).of(2.90322), value: 9, events_count: 3}
          ])
        end
      end

      context "with multiple groups" do
        let(:grouped_by) { %w[region country] }

        it "returns the sum of values grouped by the provided groups" do
          event_store.aggregation_property = billable_metric.field_name
          event_store.numeric_property = true

          result = event_store.grouped_prorated_sum(period_duration: 31)

          expect(grouped_prorated_to_h(result)).to match_array(
            [
              {
                groups: {"country" => "united kingdom", "region" => "europe"},
                prorated_value: within(0.00001).of(1.93548), value: 5, events_count: 1
              },
              {
                groups: {"country" => nil, "region" => nil},
                prorated_value: within(0.00001).of(2.64516), value: 6, events_count: 2
              },
              {
                groups: {"country" => "france", "region" => "europe"},
                prorated_value: within(0.00001).of(1.87096), value: 4, events_count: 2
              }
            ]
          )
        end
      end
    end
  end

  if include_feature?(:weighted_sum)
    describe "#weighted_sum" do
      let(:started_at) { Time.zone.parse("2023-03-01") }

      let(:events_values) do
        [
          {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 2},
          {timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3},
          {timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1},
          {timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4},
          {timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2},
          {timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10},
          {timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10}
        ]
      end

      let(:events) do
        events_values.map do |values|
          properties = {}
          properties[:region] = values[:region] if values[:region]

          create_event(
            value: values[:value],
            timestamp: values[:timestamp],
            properties:,
            charge_filter: values[:charge_filter],
            created_at: values[:created_at]
          )
        end
      end

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the weighted sum of event properties" do
        result = event_store.weighted_sum

        expect(result.value.round(5)).to eq(0.02218)
        expect(result.variation).to eq(0)
        expect(result.events_count).to eq(7)
      end

      context "with a single event" do
        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 1000}
          ]
        end

        it "returns the weighted sum of event properties" do
          result = event_store.weighted_sum

          expect(result.value.round(5)).to eq(870.96774) # 4 / 31 * 0 + 27 / 31 * 1000
          expect(result.variation).to eq(1000)
          expect(result.events_count).to eq(1)
        end
      end

      context "with no events" do
        let(:events_values) { [] }

        it "returns the weighted sum of event properties" do
          result = event_store.weighted_sum

          expect(result.value.round(5)).to eq(0.0)
          expect(result.variation).to eq(0)
          expect(result.events_count).to eq(0)
        end
      end

      context "with events with the same timestamp" do
        # NOTE: created_at is also identical to cover batch-ingested events that share
        #       timestamp, value and created_at. They must be summed, not deduplicated.
        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 3, created_at: Time.zone.parse("2023-03-05 12:00:00.000")},
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 3, created_at: Time.zone.parse("2023-03-05 12:00:00.000")}
          ]
        end

        it "returns the weighted sum of event properties" do
          expect(event_store.weighted_sum.value.round(5)).to eq(5.22581) # 4 / 31 * 0 + 27 / 31 * 6
        end
      end

      context "with initial value" do
        let(:initial_value) { 1000 }

        it "uses the initial value in the aggregation" do
          result = event_store.weighted_sum(initial_value:)

          expect(result.value.round(5)).to eq(1000.02218)
          expect(result.variation).to eq(0)
          expect(result.events_count).to eq(7)
        end

        context "without events" do
          let(:events_values) { [] }

          it "uses only the initial value in the aggregation" do
            result = event_store.weighted_sum(initial_value:)

            expect(result.value.round(5)).to eq(1000.0)
            expect(result.variation).to eq(0)
            expect(result.events_count).to eq(0)
          end
        end
      end

      context "with filters" do
        let(:matching_filters) { {region: ["europe"]} }

        let(:charge_filter) { create(:charge_filter, charge:) }

        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-04 00:00:00.000"), value: 1000, region: "us"},
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 1000, region: "europe", charge_filter:}
          ]
        end

        it "returns the weighted sum of event properties scoped to the group" do
          expect(event_store.weighted_sum.value.round(5)).to eq(870.96774) # 4 / 31 * 0 + 27 / 31 * 1000
        end
      end

      context "when from_datetime has microsecond precision and event has millisecond precision" do
        let(:boundaries) do
          {
            from_datetime: Time.zone.parse("2023-03-01 00:00:00.000000") + 0.000285,
            to_datetime: Time.zone.parse("2023-03-31").end_of_day,
            charges_duration: 31
          }
        end

        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-01 00:00:00.000"), value: 5}
          ]
        end

        it "includes the event in the weighted sum" do
          result = event_store.weighted_sum
          expect(result.value.round(5)).to eq(5.0)
        end
      end
    end
  end

  if include_feature?(:weighted_sum_breakdown)
    describe "#weighted_sum_breakdown" do
      let(:started_at) { Time.zone.parse("2023-03-01") }

      let(:events_values) do
        [
          {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 2},
          {timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3},
          {timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1},
          {timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4},
          {timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2},
          {timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10},
          {timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10}
        ]
      end

      let(:events) do
        events_values.map do |values|
          properties = {}
          properties[:region] = values[:region] if values[:region]

          create_event(
            value: values[:value],
            timestamp: values[:timestamp],
            properties:,
            charge_filter: values[:charge_filter],
            created_at: values[:created_at]
          )
        end
      end

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the weighted sum of event properties" do
        expected_breakdown = [
          [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 0.0, 0.0, 345600, 0.0],
          [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 2, 2, 3600, within(0.00001).of(0.00268)],
          [format_timestamp("2023-03-05T01:00:00.000Z", precision: 5), 3, 5, 1800, within(0.00001).of(0.00336)],
          [format_timestamp("2023-03-05T01:30:00.000Z", precision: 5), 1, 6, 1800, within(0.00001).of(0.00403)],
          [format_timestamp("2023-03-05T02:00:00.000Z", precision: 5), -4, 2, 7200, within(0.00001).of(0.00537)],
          [format_timestamp("2023-03-05T04:00:00.000Z", precision: 5), -2, 0.0, 3600, 0.0],
          [format_timestamp("2023-03-05T05:00:00.000Z", precision: 5), 10, 10, 1800, within(0.00001).of(0.00672)],
          [format_timestamp("2023-03-05T05:30:00.000Z", precision: 5), -10, 0.0, 2313000, 0.0],
          [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 0.0, 0.0, 0.0]
        ]
        expect(event_store.weighted_sum_breakdown).to match(expected_breakdown)
      end

      context "with a single event" do
        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 1000}
          ]
        end

        it "returns the weighted sum of event properties" do
          expected_breakdown = [
            [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 0.0, 0.0, 345600, 0.0],
            [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 1000, 1000, 2332800, within(0.00001).of(870.96774)],
            [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 1000, 0.0, 0.0]
          ]
          expect(event_store.weighted_sum_breakdown).to match(expected_breakdown)
        end
      end

      context "with no events" do
        let(:events_values) { [] }

        it "returns the weighted sum of event properties" do
          expect(event_store.weighted_sum_breakdown).to match([
            [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 0.0, 0.0, 2678400, 0.0],
            [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 0.0, 0.0, 0.0]
          ])
        end
      end

      context "with events with the same timestamp" do
        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 3},
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 3}
          ]
        end

        it "returns the weighted sum of event properties" do
          expected_breakdown = [
            [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 0, 0, 345600, 0.0],
            [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 3, 3, 0, 0.0],
            [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 3, 6, 2332800, within(0.00001).of(5.22580)],
            [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 6, 0.0, 0.0]
          ]
          expect(event_store.weighted_sum_breakdown).to match(expected_breakdown)
        end
      end

      context "with initial value" do
        let(:initial_value) { 1000 }

        it "uses the initial value in the aggregation" do
          expected_breakdown = [
            [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 1000, 1000, 345600, within(0.00001).of(129.03225)],
            [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 2, 1002, 3600, within(0.00001).of(1.34677)],
            [format_timestamp("2023-03-05T01:00:00.000Z", precision: 5), 3, 1005, 1800, within(0.00001).of(0.67540)],
            [format_timestamp("2023-03-05T01:30:00.000Z", precision: 5), 1, 1006, 1800, within(0.00001).of(0.67607)],
            [format_timestamp("2023-03-05T02:00:00.000Z", precision: 5), -4, 1002, 7200, within(0.00001).of(2.69354)],
            [format_timestamp("2023-03-05T04:00:00.000Z", precision: 5), -2, 1000, 3600, within(0.00001).of(1.34408)],
            [format_timestamp("2023-03-05T05:00:00.000Z", precision: 5), 10, 1010, 1800, within(0.00001).of(0.67876)],
            [format_timestamp("2023-03-05T05:30:00.000Z", precision: 5), -10, 1000, 2313000, within(0.00001).of(863.57526)],
            [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 1000, 0.0, 0.0]
          ]
          expect(event_store.weighted_sum_breakdown(initial_value:)).to match(expected_breakdown)
        end

        context "without events" do
          let(:events_values) { [] }

          it "uses only the initial value in the aggregation" do
            expected_breakdown = [
              [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 1000, 1000, 2678400, 1000],
              [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 1000, 0.0, 0.0]
            ]
            expect(event_store.weighted_sum_breakdown(initial_value:)).to match(expected_breakdown)
          end
        end
      end

      context "with filters" do
        let(:matching_filters) { {region: ["europe"]} }

        let(:charge_filter) { create(:charge_filter, charge:) }

        let(:events_values) do
          [
            {timestamp: Time.zone.parse("2023-03-04 00:00:00.000"), value: 1000, region: "us"},
            {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 1000, region: "europe", charge_filter:}
          ]
        end

        it "returns the weighted sum of event properties scoped to the group" do
          expected_breakdown = [
            [format_timestamp("2023-03-01T00:00:00.000Z", precision: 5), 0, 0, 345600, 0.0],
            [format_timestamp("2023-03-05T00:00:00.000Z", precision: 5), 1000, 1000, 2332800, within(0.00001).of(870.96774)],
            [format_timestamp("2023-04-01T00:00:00.000Z", precision: 5), 0.0, 1000, 0.0, 0.0]
          ]
          expect(event_store.weighted_sum_breakdown).to match(expected_breakdown)
        end
      end
    end
  end

  if include_feature?(:grouped_weighted_sum)
    describe "#grouped_weighted_sum" do
      let(:grouped_by) { %w[agent_name other] }

      let(:started_at) { Time.zone.parse("2023-03-01") }

      let(:events_values) do
        [
          {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 2, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, agent_name: "frodo"},
          {timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, agent_name: "frodo"},

          {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 2, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10, agent_name: "aragorn"},
          {timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10, agent_name: "aragorn"},

          {timestamp: Time.zone.parse("2023-03-05 00:00:00.000"), value: 2},
          {timestamp: Time.zone.parse("2023-03-05 01:00:00"), value: 3},
          {timestamp: Time.zone.parse("2023-03-05 01:30:00"), value: 1},
          {timestamp: Time.zone.parse("2023-03-05 02:00:00"), value: -4},
          {timestamp: Time.zone.parse("2023-03-05 04:00:00"), value: -2},
          {timestamp: Time.zone.parse("2023-03-05 05:00:00"), value: 10},
          {timestamp: Time.zone.parse("2023-03-05 05:30:00"), value: -10}
        ]
      end

      let(:events) do
        events_values.map do |values|
          properties = {}
          properties["region"] = values[:region] if values[:region]
          properties["agent_name"] = values[:agent_name] if values[:agent_name]

          create_event(
            timestamp: values[:timestamp],
            value: values[:value],
            properties:
          )
        end
      end

      before do
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true
      end

      it "returns the weighted sum of event properties" do
        result = event_store.grouped_weighted_sum

        expect(result.count).to eq(3)

        null_group = result.find { |v| v.groups["agent_name"].nil? }
        expect(null_group.groups["agent_name"]).to be_nil
        expect(null_group.groups["other"]).to be_nil
        expect(null_group.value.round(5)).to eq(0.02218)
        expect(null_group.variation).to eq(0)
        expect(null_group.events_count).to eq(7)

        (result - [null_group]).each do |row|
          expect(row.groups["agent_name"]).not_to be_nil
          expect(row.groups["other"]).to be_nil
          expect(row.value.round(5)).to eq(0.02218)
          expect(row.variation).to eq(0)
          expect(row.events_count).to eq(7)
        end
      end

      context "with no events" do
        let(:events_values) { [] }

        it "returns the weighted sum of event properties" do
          result = event_store.grouped_weighted_sum

          expect(result.count).to eq(0)
        end
      end

      context "with initial values" do
        let(:initial_values) do
          [
            {groups: {"agent_name" => "frodo", "other" => nil}, value: 1000},
            {groups: {"agent_name" => "aragorn", "other" => nil}, value: 1000},
            {groups: {"agent_name" => nil, "other" => nil}, value: 1000}
          ]
        end

        it "uses the initial value in the aggregation" do
          result = event_store.grouped_weighted_sum(initial_values:)

          expect(result.count).to eq(3)

          null_group = result.find { |v| v.groups["agent_name"].nil? }
          expect(null_group.groups["agent_name"]).to be_nil
          expect(null_group.groups["other"]).to be_nil
          expect(null_group.value.round(5)).to eq(1000.02218)
          expect(null_group.variation).to eq(0)
          expect(null_group.events_count).to eq(7)

          (result - [null_group]).each do |row|
            expect(row.groups["agent_name"]).not_to be_nil
            expect(row.groups["other"]).to be_nil
            expect(row.value.round(5)).to eq(1000.02218)
            expect(row.variation).to eq(0)
            expect(row.events_count).to eq(7)
          end
        end

        context "without events" do
          let(:events_values) { [] }

          it "uses only the initial value in the aggregation" do
            result = event_store.grouped_weighted_sum(initial_values:)

            expect(result.count).to eq(3)

            null_group = result.find { |v| v.groups["agent_name"].nil? }
            expect(null_group.groups["agent_name"]).to be_nil
            expect(null_group.groups["other"]).to be_nil
            expect(null_group.value.round(5)).to eq(1000)
            expect(null_group.variation).to eq(0)
            expect(null_group.events_count).to eq(0)

            (result - [null_group]).each do |row|
              expect(row.groups["agent_name"]).not_to be_nil
              expect(row.groups["other"]).to be_nil
              expect(row.value.round(5)).to eq(1000)
              expect(row.variation).to eq(0)
              expect(row.events_count).to eq(0)
            end
          end
        end
      end
    end
  end

  describe "recurring metric with previous subscription" do
    let(:previous_plan) { create(:plan, organization:) }
    let(:previous_charge) { create(:standard_charge, organization:, billable_metric:, plan: previous_plan) }
    let(:previous_subscription) do
      create(:subscription, plan: previous_plan, organization:, customer:, status: :terminated, started_at: started_at - 3.months)
    end
    let(:subscription) do
      create(
        :subscription,
        customer:,
        started_at:,
        previous_subscription:,
        external_id: previous_subscription.external_id
      )
    end

    let(:previous_events) do
      # Events before subscription.started_at with previous charge (different charge_id)
      create_event(
        timestamp: subscription_started_at - 2.days,
        value: 100,
        properties: {"region" => "europe", "country" => "france"},
        transaction_id: SecureRandom.uuid,
        event_charge: previous_charge
      )

      create_event(
        timestamp: subscription_started_at - 1.day,
        value: 50,
        properties: {"region" => "europe"},
        transaction_id: SecureRandom.uuid,
        event_charge: previous_charge
      )
    end

    before do
      event_store.use_from_boundary = false
      event_store.aggregation_property = billable_metric.field_name
      event_store.numeric_property = true

      previous_events
    end

    it "includes events from before subscription.started_at" do
      result = event_store.sum

      expect(result.events_count).to eq(7) # 5 from current period + 2 from before
      expect(result.value).to eq(165) # 15 from current period + 100 + 50 from before
    end

    context "with charge filters" do
      let(:charge_filter) { create(:charge_filter, charge:) }
      let(:previous_charge_filter) { create(:charge_filter, charge: previous_charge) }
      let(:matching_filters) { {"region" => ["europe"], "country" => ["france"]} }

      let(:previous_events) do
        # Previous event matching the filter
        create_event(
          timestamp: subscription_started_at - 1.day,
          value: 200,
          properties: {"region" => "europe", "country" => "france"},
          transaction_id: SecureRandom.uuid,
          event_charge: previous_charge,
          charge_filter: previous_charge_filter
        )

        # Previous event NOT matching the filter
        create_event(
          timestamp: subscription_started_at - 2.days,
          value: 999,
          properties: {"region" => "asia", "country" => "japan"},
          transaction_id: SecureRandom.uuid,
          event_charge: previous_charge,
          charge_filter: previous_charge_filter
        )
      end

      it "includes only filtered events from before subscription.started_at" do
        result = event_store.sum

        expect(result.events_count).to eq(3) # 2 from current period + 1 from before
        expect(result.value).to eq(204) # 4 from current period + 200 from before (999 (asia/japan) doesn't match)
      end
    end
  end

  if include_feature?(:distinct_charges_and_filters)
    describe "#distinct_charges_and_filters" do
      let(:charge_filter) { create(:charge_filter, charge:) }

      let(:events) { nil }

      before do
        create_enriched_event(
          timestamp: boundaries[:from_datetime] + 12.days,
          value: 12,
          properties: {billable_metric.field_name => 12},
          charge_filter:
        )
      end

      it "returns distinct charges and filters" do
        expect(event_store.distinct_charges_and_filters).to match_array([[charge.id, charge_filter.id]])
      end

      context "when charge_filter is nil" do
        let(:charge_filter) { nil }

        it "returns the distinct event codes" do
          expect(event_store.distinct_charges_and_filters).to match_array([[charge.id, nil]])
        end
      end

      context "when codes are provided" do
        it "returns only the charges and filters matching the provided codes" do
          expect(event_store.distinct_charges_and_filters(codes: [code])).to match_array([[charge.id, charge_filter.id]])
          expect(event_store.distinct_charges_and_filters(codes: ["unknown_code"])).to eq([])
        end
      end
    end
  end

  if include_feature?(:distinct_codes_and_property_combinations)
    describe "#distinct_codes_and_property_combinations" do
      let(:events) { nil }

      before do
        create_event(timestamp: subscription_started_at + 1.day, value: 1, properties: {"region" => "eu", "provider" => "aws"})
        create_event(timestamp: subscription_started_at + 2.days, value: 1, properties: {"region" => "eu", "provider" => "aws"})
        create_event(timestamp: subscription_started_at + 3.days, value: 1, properties: {"region" => "us", "provider" => "gcp"})
        create_event(timestamp: subscription_started_at + 4.days, value: 1, properties: {"region" => "eu", "extra" => "ignored"})
      end

      it "returns the distinct property combinations sliced to the filter keys" do
        result = event_store.distinct_codes_and_property_combinations(codes: [code], filter_keys: %w[region provider])

        expect(result).to match_array([
          [code, {"region" => "eu", "provider" => "aws"}],
          [code, {"region" => "us", "provider" => "gcp"}],
          [code, {"region" => "eu"}]
        ])
      end

      it "ignores property keys that are not filter keys" do
        result = event_store.distinct_codes_and_property_combinations(codes: [code], filter_keys: ["region"])

        expect(result).to match_array([
          [code, {"region" => "eu"}],
          [code, {"region" => "us"}]
        ])
      end

      context "when no filter keys are given" do
        it "returns the default bucket combination" do
          result = event_store.distinct_codes_and_property_combinations(codes: [code], filter_keys: [])

          expect(result).to eq([[code, {}]])
        end
      end

      context "when no codes are given" do
        it "returns an empty array" do
          result = event_store.distinct_codes_and_property_combinations(codes: [], filter_keys: %w[region provider])

          expect(result).to eq([])
        end
      end

      context "with events outside the boundaries" do
        before do
          create_event(
            timestamp: boundaries[:to_datetime] + 1.day,
            value: 1,
            properties: {"region" => "apac", "provider" => "azure"}
          )
        end

        it "excludes them from the combinations" do
          result = event_store.distinct_codes_and_property_combinations(codes: [code], filter_keys: %w[region provider])

          expect(result).not_to include([code, {"region" => "apac", "provider" => "azure"}])
        end
      end
    end
  end
end
