# frozen_string_literal: true

RSpec.describe Utils::ApiLog do
  subject(:api_log) { described_class }

  let(:api_key) { create(:api_key) }

  let(:fake_request) do
    instance_double(
      "ActionDispatch::Request",
      user_agent: "RSpec",
      params: {parameters: [1, 2, 3, 4]},
      path: "/api/v1/customers",
      base_url: "https://lago.test",
      method_symbol: :post,
      request_id: "1234"
    )
  end

  let(:fake_response) do
    instance_double(
      "ActionDispatch::Response",
      status: 200,
      body: {"success" => true}.to_json
    )
  end

  before do
    allow(CurrentContext).to receive(:api_key_id).and_return(api_key.id)
    travel_to(Time.zone.parse("2023-03-22 12:00:00"))
  end

  describe ".produce", :capture_kafka_messages do
    let(:organization) { create(:organization) }

    context "when kafka is configured" do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = "kafka"
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = "api_logs"
      end

      after do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = nil
      end

      it "produces the event on kafka" do
        api_log.produce(fake_request, fake_response, organization:)

        expect(karafka_producer).to have_received(:produce_async).with(
          topic: "api_logs",
          key: "#{organization.id}--1234",
          payload: {
            request_id: "1234",
            organization_id: organization.id,
            api_key_id: api_key.id,
            api_version: "v1",
            client: "RSpec",
            request_body: {parameters: [1, 2, 3, 4]},
            request_path: "/api/v1/customers",
            request_origin: "https://lago.test",
            http_method: :post,
            request_response: {"success" => true},
            http_status: 200,
            logged_at: Time.current.iso8601[...-1],
            created_at: Time.current.iso8601[...-1]
          }.to_json
        )
      end

      context "when request_id is empty" do
        let(:fake_request) do
          instance_double(
            "ActionDispatch::Request",
            user_agent: "RSpec",
            params: {parameters: [1, 2, 3, 4]},
            path: "/api/v1/customers",
            base_url: "https://lago.test",
            method_symbol: :post,
            request_id: ""
          )
        end

        it "generates a random uuid" do
          utils = api_log.new(fake_request, fake_response, organization:)
          utils.produce
          expect(utils.send(:payload)[:request_id]).to match Regex::UUID
        end
      end
    end

    context "when kafka is not configured" do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = nil
      end

      it "does not produce message" do
        api_log.produce(fake_request, fake_response, organization:)
        expect(karafka_producer).not_to have_received(:produce_async)
      end
    end

    [
      {exception: WaterDrop::Errors::ProduceError, message: "#<Rdkafka::RdkafkaError: Local: Unknown topic (unknown_topic)>"},
      {exception: WaterDrop::Errors::MessageInvalidError, message: "Message is too large"}
    ].each do |error_context|
      exception = error_context[:exception]
      message = error_context[:message]
      context "when producer raises #{exception}" do
        subject(:produce) { api_log.produce(fake_request, fake_response, organization:) }

        before do
          allow(karafka_producer).to receive(:produce_async).and_raise(exception.new(message))
        end

        context "when sentry is configured", :sentry do
          it "captures the exception and returns false" do
            expect { produce }.not_to raise_error
            expect(sentry_events).to include_sentry_event(exception: exception, message: message)
          end
        end

        context "when sentry is not configured" do
          it "re-raises the error" do
            expect { produce }.to raise_error(exception, message)
            expect(sentry_events).to be_empty
          end
        end
      end
    end
  end

  describe ".available?" do
    subject { api_log.available? }

    context "without clickhouse" do
      before do
        ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
      end

      it { is_expected.to be_falsey }
    end

    context "without kafka vars" do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = nil
        ENV["LAGO_CLICKHOUSE_ENABLED"] = "true"
      end

      it { is_expected.to be_falsey }
    end

    context "with everything configured" do
      before do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = "kafka"
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = "api_logs"
        ENV["LAGO_CLICKHOUSE_ENABLED"] = "true"
      end

      after do
        ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
        ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = nil
      end

      it { is_expected.to be_truthy }
    end
  end
end
