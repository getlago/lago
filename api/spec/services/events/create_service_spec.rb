# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::CreateService do
  subject(:create_service) do
    described_class.new(
      organization:,
      params: create_args,
      timestamp: creation_timestamp,
      metadata:
    )
  end

  let(:organization) { create(:organization) }

  let(:code) { "sum_agg" }
  let(:external_subscription_id) { SecureRandom.uuid }
  let(:timestamp) { Time.current.to_f }
  let(:transaction_id) { SecureRandom.uuid }
  let(:precise_total_amount_cents) { nil }

  let(:creation_timestamp) { Time.current.to_f }

  let(:create_args) do
    {
      external_subscription_id:,
      code:,
      transaction_id:,
      precise_total_amount_cents:,
      properties: {foo: "bar"},
      timestamp:
    }
  end

  let(:metadata) { {} }

  describe "#call" do
    it "creates an event" do
      result = nil

      expect { result = create_service.call }.to change(Event, :count).by(1)

      expect(result).to be_success
      expect(result.event).to have_attributes(
        external_subscription_id:,
        transaction_id:,
        code:,
        timestamp: Time.zone.at(BigDecimal(timestamp.to_s)),
        properties: {"foo" => "bar"},
        precise_total_amount_cents: nil
      )
    end

    it "enqueues a post processing job" do
      expect { create_service.call }.to have_enqueued_job(Events::PostProcessJob)
    end

    context "when event already exists" do
      let(:existing_event) do
        create(
          :event,
          organization:,
          transaction_id: create_args[:transaction_id],
          external_subscription_id:
        )
      end

      before { existing_event }

      it "returns an error" do
        result = 0

        expect { result = create_service.call }.not_to change(Event, :count)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:transaction_id)
        expect(result.error.messages[:transaction_id]).to include("value_already_exist")
      end
    end

    context "when timestamp is not present in the payload" do
      let(:timestamp) { nil }

      it "creates an event by setting the timestamp to the current datetime" do
        result = create_service.call

        expect(result).to be_success
        expect(result.event.timestamp).to eq(Time.zone.at(creation_timestamp))
      end
    end

    context "when timestamp is given as string" do
      let(:timestamp) { Time.current.to_f.to_s }

      it "creates an event by setting timestamp" do
        result = create_service.call

        expect(result).to be_success
        expect(result.event.timestamp).to eq(Time.zone.at(BigDecimal(timestamp)))
      end
    end

    context "when timestamp is sent with decimal precision" do
      let(:timestamp) { DateTime.parse("2023-09-04T15:45:12.344Z").to_f }

      it "creates an event by keeping the millisecond precision" do
        result = create_service.call

        expect(result).to be_success
        expect(result.event.timestamp.iso8601(3)).to eq("2023-09-04T15:45:12.344Z")
      end
    end

    context "when timestamp is sent with decimal fractions represented by repeating floats" do
      let(:timestamps) { %w[1780586634.1 1780586634.2 1780586634.3] }

      it "creates events with the received timestamp precision" do
        results = timestamps.map do |received_timestamp|
          described_class.call(
            organization:,
            params: create_args.merge(timestamp: received_timestamp, transaction_id: SecureRandom.uuid),
            timestamp: creation_timestamp,
            metadata:
          )
        end

        expect(results).to all(be_success)
        expect(results.map { |result| result.event.timestamp.iso8601(9) }).to eq([
          "2026-06-04T15:23:54.100000000Z",
          "2026-06-04T15:23:54.200000000Z",
          "2026-06-04T15:23:54.300000000Z"
        ])
      end
    end

    context "when timestamp is given in a wrong format" do
      let(:timestamp) { Time.current.to_s }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.messages).to include({timestamp: ["invalid_format"]})
      end
    end

    context "when kafka is configured", :capture_kafka_messages do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = "kafka"
        ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"] = "raw_events"
      end

      it "produces the event on kafka" do
        create_service.call

        expect(karafka_producer).to have_received(:produce_many_async) do |messages|
          expect(messages.size).to eq(1)
        end
      end
    end

    context "with an expression configured on the billable metric" do
      let(:billable_metric) { create(:billable_metric, code:, organization:, field_name: "result", expression: "event.properties.left + event.properties.right") }

      let(:create_args) do
        {
          external_subscription_id:,
          code:,
          transaction_id:,
          precise_total_amount_cents:,
          properties: {left: "1", right: "2"},
          timestamp:
        }
      end

      before do
        billable_metric
      end

      it "creates an event and updates the field name with the result of the expression" do
        result = create_service.call

        expect(result).to be_success
        expect(result.event.properties["result"]).to eq("3.0")
      end

      context "when not all the event properties are not provided" do
        let(:create_args) do
          {
            external_subscription_id:,
            code:,
            transaction_id:,
            precise_total_amount_cents:,
            properties: {},
            timestamp:
          }
        end

        it "returns a service failure when the expression fails to evaluate" do
          result = create_service.call

          expect(result).to be_failure
        end
      end
    end

    context "with a precise_total_amount_cents" do
      let(:precise_total_amount_cents) { "123.45" }

      it "creates an event with the precise_total_amount_cents" do
        result = create_service.call

        expect(result).to be_success
        expect(result.event.precise_total_amount_cents).to eq(123.45)
      end

      context "when precise_total_amount_cents is not a valid decimal value" do
        let(:precise_total_amount_cents) { "asdfa" }

        it "creates an event" do
          result = create_service.call

          expect(result).to be_success
          expect(result.event.precise_total_amount_cents).to eq(0)
        end
      end
    end
  end
end
