# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::CreateBatchService do
  subject(:create_batch_service) do
    described_class.new(
      organization:,
      events_params:,
      timestamp: creation_timestamp,
      metadata:
    )
  end

  let(:organization) { create(:organization) }
  let(:timestamp) { Time.parse("2024-01-01T01:02:03.123456Z").to_f }
  let(:code) { "sum_agg" }
  let(:metadata) { {} }
  let(:creation_timestamp) { Time.current.to_f }
  let(:precise_total_amount_cents) { "123.34" }
  let(:external_subscription_id) { "sub_12345" }
  let(:events_params) { build_params }

  def build_params(count: 3, &block)
    events = []
    count.times do |i|
      event = {
        external_customer_id: "cust_#{i}",
        external_subscription_id:,
        code:,
        transaction_id: "txn_#{i}",
        precise_total_amount_cents:,
        properties: {foo: "bar_#{i}"},
        timestamp:
      }
      yield(event, i) if block_given?

      events << event
    end

    {events:}
  end

  def test_validation_failure(expected_errors)
    result = nil

    expect { result = create_batch_service.call }.not_to change(Event, :count)

    expect(result).not_to be_success
    expect(result.error).to be_a(BaseService::ValidationFailure)
    expect(result.error.messages).to eq expected_errors
  end

  describe ".call" do
    it "creates all events" do
      result = nil

      expect { result = create_batch_service.call }.to change(Event, :count).by(3)

      expect(result).to be_success
    end

    it "persists events with correct attributes" do
      result = create_batch_service.call

      expect(result).to be_success

      expect(result.events.count).to eq(3)
      result.events.each_with_index do |event, index|
        reloaded = Event.find(event.id)
        expected_params = events_params[:events][index]

        expect(reloaded.organization_id).to eq(organization.id)
        expect(reloaded.code).to eq("sum_agg")
        expect(reloaded.transaction_id).to eq(expected_params[:transaction_id])
        expect(reloaded.external_subscription_id).to eq(expected_params[:external_subscription_id])
        expect(reloaded.properties).to eq({"foo" => "bar_#{index}"})
        expect(reloaded.precise_total_amount_cents).to eq(BigDecimal("123.34"))
        expect(reloaded.timestamp).to eq(Time.parse("2024-01-01T01:02:03.123456Z"))
      end
    end

    it "enqueues post processing jobs with correct event arguments" do
      result = create_batch_service.call

      expect(Events::PostProcessJob).to have_been_enqueued.exactly(3).times
      result.events.each do |event|
        expect(Events::PostProcessJob).to have_been_enqueued.with(event:)
      end
    end

    context "when no events are provided" do
      let(:events_params) { build_params(count: 0) }

      it "returns a no_events error" do
        test_validation_failure({events: ["no_events"]})
      end
    end

    context "when events count is at the limit" do
      let(:events_params) { build_params(count: 100) }

      it "returns a too big error" do
        result = nil

        expect { result = create_batch_service.call }.to change(Event, :count).by(100)

        expect(result).to be_success
      end
    end

    context "when events count is too big" do
      let(:events_params) { build_params(count: 101) }

      it "returns a too big error" do
        test_validation_failure({events: ["too_many_events"]})
      end
    end

    context "with at least one invalid event" do
      context "with duplicate transaction_id in consecutive positions" do
        let(:events_params) { build_params(count: 2) { |event| event[:transaction_id] = "duplicate_txn" } }

        it "returns a duplicate transaction_id error for the second event" do
          test_validation_failure({1 => {transaction_id: ["value_already_exist"]}})
        end
      end

      # We have different error/issues depending on whether another error is saved afterward as PG will roll-back the
      # transaction when an error occurs due to duplicate.
      [:beginning, :middle, :end].each do |duplicate_event_occurence|
        context "with already existing event (#{duplicate_event_occurence})" do
          let(:existing_event) do
            create(:event, organization:, transaction_id: SecureRandom.uuid, external_subscription_id:)
          end
          let(:duplicate_event_index) do
            case duplicate_event_occurence
            when :beginning then 0
            when :middle then 2
            when :end then 4
            end
          end
          let(:events_params) do
            build_params(count: 5) do |event, index|
              event[:transaction_id] = existing_event.transaction_id if index == duplicate_event_index
            end
          end

          before { existing_event }

          it "returns a duplicate transaction_id error for the duplicate event" do
            test_validation_failure({duplicate_event_index => {transaction_id: ["value_already_exist"]}})
          end
        end
      end
    end

    context "with duplicate transaction_id in non-consecutive positions" do
      let(:events_params) do
        build_params(count: 4) do |event, index|
          event[:transaction_id] = "duplicate_txn" if index == 0 || index == 2
        end
      end

      it "returns a duplicate transaction_id error for the duplicate at index 2" do
        test_validation_failure({2 => {transaction_id: ["value_already_exist"]}})
      end
    end

    context "with multiple duplicate transaction_ids" do
      let(:events_params) do
        build_params(count: 4) do |event, index|
          event[:transaction_id] = "duplicate_txn_a" if index == 0 || index == 2
          event[:transaction_id] = "duplicate_txn_b" if index == 1 || index == 3
        end
      end

      it "returns duplicate errors for all duplicates" do
        test_validation_failure({
          2 => {transaction_id: ["value_already_exist"]},
          3 => {transaction_id: ["value_already_exist"]}
        })
      end
    end

    context "with three events having the same transaction_id" do
      let(:events_params) { build_params(count: 3) { |event| event[:transaction_id] = "duplicate_txn" } }

      it "returns errors for the second and third events" do
        test_validation_failure({
          1 => {transaction_id: ["value_already_exist"]},
          2 => {transaction_id: ["value_already_exist"]}
        })
      end
    end

    context "with already existing event" do
      let(:existing_event) do
        create(:event, organization:, transaction_id: "existing_txn", external_subscription_id:)
      end
      let(:events_params) do
        build_params(count: 2) do |event, index|
          event[:transaction_id] = "existing_txn" if index == 1
        end

        before { existing_event }

        it "returns an error for the duplicate" do
          test_validation_failure({1 => {transaction_id: ["value_already_exist"]}})
        end
      end

      context "with already existing event at first position" do
        let(:existing_event) do
          create(:event, organization:, transaction_id: "existing_txn", external_subscription_id:)
        end
        let(:events_params) do
          build_params(count: 2) do |event, index|
            event[:transaction_id] = "existing_txn" if index == 0
          end
        end

        before { existing_event }

        it "returns an error for the first event" do
          test_validation_failure({0 => {transaction_id: ["value_already_exist"]}})
        end
      end
    end

    context "when timestamp is not present in the payload" do
      let(:events_params) { build_params(count: 1) { it.delete(:timestamp) } }

      it "creates an event by setting the timestamp to the current datetime" do
        result = create_batch_service.call

        expect(result).to be_success
        expect(result.events.first.timestamp).to eq(Time.zone.at(creation_timestamp))
      end
    end

    context "when timestamp is given as string" do
      let(:timestamp) { Time.current.to_f.to_s }
      let(:events_params) { build_params(count: 1) { |event| event[:timestamp] = timestamp } }

      it "creates an event by setting timestamp" do
        result = create_batch_service.call

        expect(result).to be_success
        expect(result.events.first.timestamp).to eq(Time.zone.at(BigDecimal(timestamp)))
      end
    end

    context "when timestamp is in a wrong format" do
      let(:timestamp) { Time.current.to_s }
      let(:events_params) { build_params(count: 1) { |event| event[:timestamp] = timestamp } }

      it "returns an error" do
        test_validation_failure({0 => {timestamp: ["invalid_format"]}})
      end
    end

    context "with an expression configured on the billable metric" do
      let(:billable_metric) { create(:billable_metric, code:, organization:, field_name: "result", expression: "concat(event.properties.foo, '-bar')") }

      before do
        billable_metric
      end

      it "creates an event and updates the field name with the result of the expression" do
        result = create_batch_service.call

        expect(result).to be_success
        result.events.each_with_index { |event, index| expect(event.properties["result"]).to eq("bar_#{index}-bar") }
      end

      context "when not all the event properties are not provided" do
        let(:events_params) { build_params(count: 1) { |event| event[:properties] = {} } }

        it "returns a failure when the expression fails to evaluate" do
          test_validation_failure({0 => "expression_evaluation_failed: Variable: foo not found"})
        end
      end
    end

    context "when timestamp is sent with decimal precision" do
      let(:timestamp) { DateTime.parse("2023-09-04T15:45:12.344Z").to_f }
      let(:events_params) { build_params(count: 1) { |event| event[:timestamp] = timestamp } }

      it "creates an event by keeping the millisecond precision" do
        result = create_batch_service.call

        expect(result).to be_success
        expect(result.events.first.timestamp.iso8601(3)).to eq("2023-09-04T15:45:12.344Z")
      end
    end

    context "when timestamp is sent with decimal fractions represented by repeating floats" do
      let(:timestamps) { %w[1780586634.1 1780586634.2 1780586634.3] }
      let(:events_params) do
        build_params(count: timestamps.count) do |event, index|
          event[:timestamp] = timestamps[index]
        end
      end

      it "creates events with the received timestamp precision" do
        result = create_batch_service.call

        expect(result).to be_success
        expect(result.events.map { |event| event.timestamp.iso8601(9) }).to eq([
          "2026-06-04T15:23:54.100000000Z",
          "2026-06-04T15:23:54.200000000Z",
          "2026-06-04T15:23:54.300000000Z"
        ])
      end
    end

    context "when kafka is configured", :capture_kafka_messages do
      let(:events_params) { build_params(count: 2) }

      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = "kafka"
        ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] = "raw_events"
      end

      after do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
        ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] = nil
      end

      it "produces all events on kafka in bulk with correct message format" do
        freeze_time do
          create_batch_service.call

          expect(karafka_producer).to have_received(:produce_many_async) do |messages|
            expect(messages.size).to eq(2)

            messages.each_with_index do |message, index|
              expected_params = events_params[:events][index]

              expect(message[:topic]).to eq("raw_events")
              expect(message[:key]).to eq("#{organization.id}-#{external_subscription_id}")

              payload = JSON.parse(message[:payload])
              expect(payload["organization_id"]).to eq(organization.id)
              expect(payload["external_subscription_id"]).to eq(external_subscription_id)
              expect(payload["transaction_id"]).to eq(expected_params[:transaction_id])
              expect(payload["code"]).to eq(code)
              expect(payload["precise_total_amount_cents"]).to eq(precise_total_amount_cents)
              expect(payload["properties"]).to eq(expected_params[:properties].stringify_keys)
              expect(payload["timestamp"]).to eq(timestamp.to_s)
              expect(payload["ingested_at"]).to eq(Time.zone.now.iso8601[...-1])
              expect(payload["source"]).to eq("http_ruby")
              expect(payload["source_metadata"]).to eq({"api_post_processed" => true})
            end
          end
        end
      end
    end

    context "when clickhouse is enabled on the organization" do
      let(:organization) { create(:organization, clickhouse_events_store: true) }

      it "does not store the event in postgres" do
        result = nil

        expect { result = create_batch_service.call }.not_to change(Event, :count)
        expect(result).to be_success
      end

      it "does not enqueue a post processing job" do
        expect { create_batch_service.call }.not_to have_enqueued_job(Events::PostProcessJob)
      end

      context "when kafka is configured", :capture_kafka_messages do
        let(:events_params) { build_params(count: 2) }

        before do
          ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = "kafka"
          ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] = "raw_events"
        end

        after do
          ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
          ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] = nil
        end

        it "produces all events on kafka with api_post_processed set to false" do
          freeze_time do
            create_batch_service.call

            expect(karafka_producer).to have_received(:produce_many_async) do |messages|
              expect(messages.size).to eq(2)

              messages.each do |message|
                payload = JSON.parse(message[:payload])
                expect(payload["source_metadata"]).to eq({"api_post_processed" => false})
              end
            end
          end
        end
      end
    end
  end
end
