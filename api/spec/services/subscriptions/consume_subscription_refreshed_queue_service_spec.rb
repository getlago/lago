# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ConsumeSubscriptionRefreshedQueueService do
  subject(:service) { described_class.new }

  let(:redis_client) { instance_double(Redis) }
  let(:redis_url) { "localhost:6379" }

  let(:bucket) do
    (
      (Time.current.to_i - 20) / described_class::SUBSCRIPTION_BUCKET_DURATION
    ) * described_class::SUBSCRIPTION_BUCKET_DURATION
  end
  let(:values) do
    [
      "#{SecureRandom.uuid}:#{subscription_id1}|#{bucket}",
      "#{SecureRandom.uuid}:#{subscription_id2}|#{bucket}"
    ]
  end
  let(:loop_values) { [values, []] }

  let(:subscription_id1) { SecureRandom.uuid }
  let(:subscription_id2) { SecureRandom.uuid }

  before do
    allow(Redis).to receive(:new).and_return(redis_client)
    allow(redis_client).to receive(:zrangebyscore).and_return(*loop_values)
    allow(redis_client).to receive(:zrem)

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LAGO_REDIS_STORE_URL").and_return(redis_url)
  end

  describe "#call" do
    it "flags all subscriptions as refreshed" do
      result = service.call

      expect(result).to be_success
      expect(Subscriptions::FlagRefreshedJob).to have_been_enqueued.with(subscription_id1)
      expect(Subscriptions::FlagRefreshedJob).to have_been_enqueued.with(subscription_id2)
    end

    it "queries with the correct threshold" do
      freeze_time do
        threshold = (Time.current - described_class::SUBSCRIPTION_BUCKET_DURATION).to_i

        service.call

        expect(redis_client).to have_received(:zrangebyscore)
          .with(described_class::REDIS_STORE_NAME, "-inf", threshold, limit: [0, described_class::BATCH_SIZE])
          .at_least(:once)
      end
    end

    it "removes processed values with zrem" do
      service.call

      expect(redis_client).to have_received(:zrem).with(described_class::REDIS_STORE_NAME, values)
    end

    context "with multiple batches" do
      let(:loop_values) { [values, values, []] }

      it "flags all subscriptions as refreshed" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).to have_been_enqueued.exactly(4).times
      end
    end

    context "with no subscriptions" do
      let(:loop_values) { [[]] }

      it "does not flag any subscriptions as refreshed" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).not_to have_been_enqueued
      end
    end

    context "when timeout is reached" do
      let(:start_time) { Time.current }

      before do
        allow(Time).to receive(:current).and_return(
          start_time,
          start_time + described_class::PROCESSING_TIMEOUT + 1.second
        )
      end

      it "stops processing" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).not_to have_been_enqueued
      end
    end

    context "when the redis env var is not present" do
      let(:redis_url) { nil }

      it "does not flag any subscriptions as refreshed" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).not_to have_been_enqueued
      end
    end

    context "when redis env vars contains redis:// prefix" do
      let(:redis_url) { "redis://localhost:6379" }

      it "flags all subscriptions as refreshed" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).to have_been_enqueued.twice

        expect(Redis).to have_received(:new).with(hash_including(url: redis_url))
      end
    end

    context "when redis env vars contains rediss:// prefix" do
      let(:redis_url) { "rediss://localhost:6379" }

      it "flags all subscriptions as refreshed" do
        result = service.call

        expect(result).to be_success
        expect(Subscriptions::FlagRefreshedJob).to have_been_enqueued.twice

        expect(Redis).to have_received(:new).with(hash_including(url: redis_url))
      end
    end
  end
end
