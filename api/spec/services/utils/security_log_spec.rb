# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::SecurityLog do
  subject(:security_log) { described_class }

  let(:karafka_producer) { instance_double(WaterDrop::Producer) }

  before do
    allow(Karafka).to receive(:producer).and_return(karafka_producer)
    allow(karafka_producer).to receive(:produce_async)
  end

  describe ".available?" do
    subject { security_log.available? }

    include_context "with security log infrastructure"

    context "when infrastructure is configured" do
      it { is_expected.to be_truthy }
    end

    context "when clickhouse is not configured" do
      let(:clickhouse_enabled) { nil }

      it { is_expected.to be_falsey }
    end

    context "when kafka bootstrap servers are not configured" do
      let(:kafka_bootstrap_servers) { nil }

      it { is_expected.to be_falsey }
    end

    context "when kafka topic is not configured" do
      let(:kafka_security_logs_topic) { nil }

      it { is_expected.to be_falsey }
    end
  end

  describe ".produce" do
    subject(:produce) do
      security_log.produce(
        organization:,
        log_type: "user",
        log_event: "user.signed_up",
        user:,
        api_key:,
        resources: {user_email: "test@example.com"},
        device_info: {browser: "Chrome"}
      )
    end

    let(:organization) { create(:organization, premium_integrations: ["security_logs"]) }
    let(:membership) { create(:membership, organization:) }
    let(:user) { membership.user }
    let(:api_key) { create(:api_key, organization:) }

    include_context "with security log infrastructure"

    before do
      allow(License).to receive(:premium?).and_return(true)
      travel_to(Time.zone.parse("2024-01-15 12:00:00"))
    end

    context "when infrastructure is configured and security_logs enabled" do
      it "produces the event on kafka" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          expect(args[:topic]).to eq("security_logs")
          expect(args[:key]).to start_with("#{organization.id}--")

          payload = JSON.parse(args[:payload])
          expect(payload["organization_id"]).to eq(organization.id)
          expect(payload["user_id"]).to eq(user.id)
          expect(payload["api_key_id"]).to eq(api_key.id)
          expect(payload["log_id"]).to be_present
          expect(payload["log_type"]).to eq("user")
          expect(payload["log_event"]).to eq("user.signed_up")
          expect(payload["device_info"]).to eq({"browser" => "Chrome"})
          expect(payload["resources"]).to eq({"user_email" => "test@example.com"})
          expect(payload["logged_at"]).to be_present
          expect(payload["created_at"]).to be_present
        end
      end
    end

    context "when infrastructure is not configured" do
      let(:clickhouse_enabled) { nil }

      it "does not produce and returns false" do
        expect(produce).to be false
        expect(karafka_producer).not_to have_received(:produce_async)
      end
    end

    context "when security_logs is not enabled for organization" do
      let(:organization) { create(:organization, premium_integrations: []) }

      it "does not produce and returns false" do
        expect(produce).to be false
        expect(karafka_producer).not_to have_received(:produce_async)
      end
    end

    context "when security_logs is not enabled but skip_organization_check is true" do
      subject(:produce) do
        security_log.produce(
          organization:,
          log_type: "user",
          log_event: "user.signed_up",
          user:,
          api_key:,
          resources: {user_email: "test@example.com"},
          skip_organization_check: true
        )
      end

      let(:organization) { create(:organization, premium_integrations: []) }

      it "produces the event on kafka" do
        expect(produce).to be true
        expect(karafka_producer).to have_received(:produce_async)
      end
    end

    context "when License is not premium" do
      before { allow(License).to receive(:premium?).and_return(false) }

      it "does not produce and returns false" do
        expect(produce).to be false
        expect(karafka_producer).not_to have_received(:produce_async)
      end
    end

    context "when user is nil" do
      let(:user) { nil }

      it "produces with nil user_id" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["user_id"]).to be_nil
        end
      end
    end

    context "when api_key is nil" do
      let(:api_key) { nil }

      it "produces with nil api_key_id" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["api_key_id"]).to be_nil
        end
      end
    end

    context "when user is not provided but CurrentContext.membership is set" do
      subject(:produce) do
        security_log.produce(
          organization:,
          log_type: "user",
          log_event: "user.signed_up",
          api_key:,
          resources: {}
        )
      end

      before do
        CurrentContext.membership = "gid://app/Membership/#{membership.id}"
      end

      after do
        CurrentContext.membership = nil
      end

      it "resolves user_id from membership" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["user_id"]).to eq(user.id)
        end
      end
    end

    context "when user is not provided and CurrentContext.api_key_id is set" do
      subject(:produce) do
        security_log.produce(
          organization:,
          log_type: "api_key",
          log_event: "api_key.created",
          api_key:,
          resources: {}
        )
      end

      before do
        CurrentContext.api_key_id = api_key.id
        CurrentContext.membership = "gid://app/Membership/#{membership.id}"
      end

      after do
        CurrentContext.api_key_id = nil
        CurrentContext.membership = nil
      end

      it "produces with nil user_id" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["user_id"]).to be_nil
        end
      end
    end

    context "when user is not provided and CurrentContext.membership is blank" do
      subject(:produce) do
        security_log.produce(
          organization:,
          log_type: "user",
          log_event: "user.signed_up",
          api_key:,
          resources: {}
        )
      end

      before do
        CurrentContext.membership = nil
      end

      it "produces with nil user_id" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["user_id"]).to be_nil
        end
      end
    end

    context "when device_info is not provided but CurrentContext.device_info is set" do
      subject(:produce) do
        security_log.produce(
          organization:,
          log_type: "user",
          log_event: "user.signed_up",
          user:,
          api_key:,
          resources: {}
        )
      end

      before { CurrentContext.device_info = {browser: "Chrome", os: "Mac OS"} }
      after { CurrentContext.device_info = nil }

      it "uses device_info from CurrentContext" do
        expect(produce).to be true

        expect(karafka_producer).to have_received(:produce_async) do |args|
          payload = JSON.parse(args[:payload])
          expect(payload["device_info"]).to eq({"browser" => "Chrome", "os" => "Mac OS"})
        end
      end
    end

    [
      {exception: WaterDrop::Errors::ProduceError, message: "#<Rdkafka::RdkafkaError: Local: Unknown topic (unknown_topic)>"},
      {exception: WaterDrop::Errors::MessageInvalidError, message: "Message is too large"}
    ].each do |error_context|
      exception = error_context[:exception]
      message = error_context[:message]
      context "when producer raises #{exception}" do
        before do
          allow(karafka_producer).to receive(:produce_async).and_raise(exception.new(message))
        end

        context "when sentry is configured", :sentry do
          it "captures the exception and returns false" do
            expect(produce).to be false
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
end
