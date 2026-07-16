# frozen_string_literal: true

require "rails_helper"
require "lago/redis_config_builder"

RSpec.describe Lago::RedisConfigBuilder do
  subject(:builder) { described_class.new }

  around do |example|
    env_keys = %w[
      REDIS_URL REDIS_PASSWORD
      LAGO_REDIS_SIDEKIQ_SENTINELS LAGO_REDIS_SIDEKIQ_MASTER_NAME
      LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS
      LAGO_REDIS_CACHE_URL LAGO_REDIS_CACHE_PASSWORD
      LAGO_REDIS_CACHE_SENTINELS LAGO_REDIS_CACHE_MASTER_NAME
    ]
    original_env = ENV.to_h.slice(*env_keys)
    env_keys.each { |key| ENV.delete(key) }
    example.run
    ENV.update(original_env)
    ENV.delete_if { |k, _| env_keys.include?(k) && !original_env.key?(k) }
  end

  describe "#sidekiq" do
    subject(:result) { builder.sidekiq }

    context "with no environment variables set" do
      before do
        ENV.delete("REDIS_URL")
        ENV.delete("REDIS_PASSWORD")
        ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
        allow(builder).to receive(:rand).and_return(1.0) # rubocop:disable RSpec/SubjectStub -- neutralize jitter
      end

      it "returns base config with the default retry window applied" do
        expect(result).to eq(
          ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE},
          timeout: 1,
          reconnect_attempts: [0.1, 0.4, 0.9, 1.6],
          middlewares: [Lago::RedisLoadingRetryMiddleware],
          custom: {loading_retry_attempts: [0.1, 0.4, 0.9, 1.6]}
        )
      end
    end

    context "with REDIS_URL set" do
      before do
        ENV["REDIS_URL"] = "redis://localhost:6379"
        ENV.delete("REDIS_PASSWORD")
        ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
      end

      it "includes the url" do
        expect(result).to include(url: "redis://localhost:6379")
      end
    end

    context "with REDIS_PASSWORD set" do
      before do
        ENV.delete("REDIS_URL")
        ENV["REDIS_PASSWORD"] = "secret"
        ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
      end

      it "includes the password" do
        expect(result).to include(password: "secret")
      end
    end

    context "with REDIS_PASSWORD empty" do
      before do
        ENV.delete("REDIS_URL")
        ENV["REDIS_PASSWORD"] = ""
        ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
      end

      it "does not include the password" do
        expect(result).not_to have_key(:password)
      end
    end

    context "with sentinels configured" do
      before do
        ENV.delete("REDIS_URL")
        ENV.delete("REDIS_PASSWORD")
        ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = "sentinel1:26379,sentinel2:26380"
      end

      it "includes sentinel config with default master name" do
        expect(result).to include(
          sentinels: [{host: "sentinel1", port: 26379}, {host: "sentinel2", port: 26380}],
          role: :master,
          name: "master"
        )
      end

      context "with custom master name" do
        before { ENV["LAGO_REDIS_SIDEKIQ_MASTER_NAME"] = "mymaster" }

        it "uses the custom master name" do
          expect(result).to include(name: "mymaster")
        end
      end

      context "with blank master name" do
        before { ENV["LAGO_REDIS_SIDEKIQ_MASTER_NAME"] = "" }

        it "falls back to default master name" do
          expect(result).to include(name: "master")
        end
      end

      context "with sentinel without port" do
        before { ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = "sentinel1" }

        it "parses sentinel without port" do
          expect(result[:sentinels]).to eq([{host: "sentinel1"}])
        end
      end

      context "with invalid sentinel port" do
        before { ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = "sentinel1:abc" }

        it "raises an error" do
          expect { result }.to raise_error(ArgumentError, /Invalid Redis sentinel port/)
        end
      end

      context "with whitespace in sentinel host and port" do
        before { ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = " sentinel1 : 26379 " }

        it "strips whitespace from host and port" do
          expect(result[:sentinels]).to eq([{host: "sentinel1", port: 26379}])
        end
      end
    end

    context "with LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS set" do
      before do
        ENV.delete("REDIS_URL")
        ENV.delete("REDIS_PASSWORD")
        ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
        ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "8"
        allow(builder).to receive(:rand).and_return(1.0) # rubocop:disable RSpec/SubjectStub -- neutralize jitter
      end

      it "generates quadratically increasing intervals within the window" do
        expect(result).to include(reconnect_attempts: [0.1, 0.4, 0.9, 1.6, 2.5])
      end

      it "wires the loading retry middleware with the same schedule" do
        expect(result).to include(
          middlewares: [Lago::RedisLoadingRetryMiddleware],
          custom: {loading_retry_attempts: [0.1, 0.4, 0.9, 1.6, 2.5]}
        )
      end

      context "with jitter" do
        before { allow(builder).to receive(:rand).and_call_original } # rubocop:disable RSpec/SubjectStub -- restore real jitter

        it "keeps each interval within +-25% of the base series and the total within the window" do
          intervals = result[:reconnect_attempts]

          expect((intervals.sum * 10).round).to be <= 80
          intervals.each_with_index do |interval, index|
            base_tenths = (index + 1)**2
            expect(interval).to be_between(
              (base_tenths * 0.75).round / 10.0,
              (base_tenths * 1.25).round / 10.0
            )
          end
        end
      end

      context "with a small window" do
        before { ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "1" }

        it "stops before the cumulative sum exceeds the window" do
          expect(result).to include(reconnect_attempts: [0.1, 0.4])
        end
      end

      context "with a non-integer window" do
        before { ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "2.5" }

        it "generates intervals within the fractional window" do
          expect(result).to include(reconnect_attempts: [0.1, 0.4, 0.9])
        end
      end

      context "with a window smaller than the first interval" do
        before { ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "0" }

        it "generates no reconnect attempts" do
          expect(result).to include(reconnect_attempts: [])
        end
      end

      context "with an invalid value" do
        before { ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "abc" }

        it "raises an error" do
          expect { result }.to raise_error(ArgumentError, /Invalid Redis retry attempts window/)
        end
      end

      context "with an empty value" do
        before { ENV["LAGO_REDIS_SIDEKIQ_RETRY_WINDOW_SECONDS"] = "" }

        it "falls back to the default retry window" do
          expect(result).to include(reconnect_attempts: [0.1, 0.4, 0.9, 1.6])
        end
      end

      context "with a reconnect_attempts override via with_options" do
        subject(:result) { builder.with_options(reconnect_attempts: 4).sidekiq }

        it "lets the override win" do
          expect(result).to include(reconnect_attempts: 4)
        end
      end
    end

    context "with sentinels and REDIS_URL set" do
      before do
        ENV["REDIS_URL"] = "redis://localhost:6379"
        ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = "sentinel1:26379"
        ENV.delete("REDIS_PASSWORD")
      end

      it "still includes sentinel config" do
        expect(result).to include(:sentinels, :role, :name)
      end
    end

    context "with all options set" do
      before do
        ENV["REDIS_URL"] = "redis://localhost:6379"
        ENV["REDIS_PASSWORD"] = "secret"
        ENV["LAGO_REDIS_SIDEKIQ_SENTINELS"] = "sentinel1:26379"
        ENV["LAGO_REDIS_SIDEKIQ_MASTER_NAME"] = "mymaster"
        allow(builder).to receive(:rand).and_return(1.0) # rubocop:disable RSpec/SubjectStub -- neutralize jitter
      end

      it "includes all config options" do
        expect(result).to eq(
          url: "redis://localhost:6379",
          ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE},
          timeout: 1,
          sentinels: [{host: "sentinel1", port: 26379}],
          role: :master,
          name: "mymaster",
          password: "secret",
          reconnect_attempts: [0.1, 0.4, 0.9, 1.6],
          middlewares: [Lago::RedisLoadingRetryMiddleware],
          custom: {loading_retry_attempts: [0.1, 0.4, 0.9, 1.6]}
        )
      end
    end
  end

  describe "#cache" do
    subject(:result) { builder.cache }

    context "with no environment variables set" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV.delete("LAGO_REDIS_CACHE_PASSWORD")
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it "returns base config" do
        expect(result).to eq(
          ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE},
          timeout: 1
        )
      end
    end

    context "with LAGO_REDIS_CACHE_URL set" do
      before do
        ENV["LAGO_REDIS_CACHE_URL"] = "redis://cache:6379"
        ENV.delete("LAGO_REDIS_CACHE_PASSWORD")
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it "includes the url" do
        expect(result).to include(url: "redis://cache:6379")
      end
    end

    context "with LAGO_REDIS_CACHE_PASSWORD set" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV["LAGO_REDIS_CACHE_PASSWORD"] = "cache_secret"
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it "includes the password" do
        expect(result).to include(password: "cache_secret")
      end
    end

    context "with LAGO_REDIS_CACHE_PASSWORD empty" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV["LAGO_REDIS_CACHE_PASSWORD"] = ""
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it "does not include the password" do
        expect(result).not_to have_key(:password)
      end
    end

    context "with sentinels configured" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV.delete("LAGO_REDIS_CACHE_PASSWORD")
        ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel1:26379,cache-sentinel2:26380"
      end

      it "includes sentinel config with default master name" do
        expect(result).to include(
          sentinels: [{host: "cache-sentinel1", port: 26379}, {host: "cache-sentinel2", port: 26380}],
          role: :master,
          name: "master"
        )
      end

      it "produces a URL-less config (the sentinel-only case used by production.rb)" do
        expect(result).not_to have_key(:url)
      end

      context "with custom master name" do
        before { ENV["LAGO_REDIS_CACHE_MASTER_NAME"] = "cache-master" }

        it "uses the custom master name" do
          expect(result).to include(name: "cache-master")
        end
      end

      context "with blank master name" do
        before { ENV["LAGO_REDIS_CACHE_MASTER_NAME"] = "" }

        it "falls back to default master name" do
          expect(result).to include(name: "master")
        end
      end

      context "with sentinel without port" do
        before { ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel" }

        it "parses sentinel without port" do
          expect(result[:sentinels]).to eq([{host: "cache-sentinel"}])
        end
      end

      context "with invalid sentinel port" do
        before { ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel:abc" }

        it "raises an error" do
          expect { result }.to raise_error(ArgumentError, /Invalid Redis sentinel port/)
        end
      end

      context "with whitespace in sentinel host and port" do
        before { ENV["LAGO_REDIS_CACHE_SENTINELS"] = " cache-sentinel : 26379 " }

        it "strips whitespace from host and port" do
          expect(result[:sentinels]).to eq([{host: "cache-sentinel", port: 26379}])
        end
      end
    end

    context "with all options set" do
      before do
        ENV["LAGO_REDIS_CACHE_URL"] = "redis://cache:6379"
        ENV["LAGO_REDIS_CACHE_PASSWORD"] = "cache_secret"
        ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel:26379"
        ENV["LAGO_REDIS_CACHE_MASTER_NAME"] = "cache-master"
      end

      it "includes all config options" do
        expect(result).to eq(
          url: "redis://cache:6379",
          ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE},
          timeout: 1,
          sentinels: [{host: "cache-sentinel", port: 26379}],
          role: :master,
          name: "cache-master",
          password: "cache_secret"
        )
      end
    end
  end

  describe "#with_options" do
    before do
      ENV.delete("REDIS_URL")
      ENV.delete("REDIS_PASSWORD")
      ENV.delete("LAGO_REDIS_SIDEKIQ_SENTINELS")
      ENV.delete("LAGO_REDIS_CACHE_URL")
      ENV.delete("LAGO_REDIS_CACHE_PASSWORD")
      ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
    end

    it "merges extra options into the sidekiq config" do
      result = builder.with_options(reconnect_attempts: 4).sidekiq
      expect(result).to include(reconnect_attempts: 4)
    end

    it "merges extra options into the cache config" do
      result = builder.with_options(pool: {size: 5}).cache
      expect(result).to include(pool: {size: 5})
    end

    it "returns self for chaining" do
      expect(builder.with_options(foo: 1)).to eq(builder)
    end

    it "merges multiple calls into the sidekiq config" do
      result = builder
        .with_options(reconnect_attempts: 4)
        .with_options(custom: "value")
        .sidekiq
      expect(result).to include(reconnect_attempts: 4, custom: "value")
    end

    it "merges multiple calls into the cache config" do
      result = builder
        .with_options(pool: {size: 5})
        .with_options(custom: "value")
        .cache
      expect(result).to include(pool: {size: 5}, custom: "value")
    end

    it "extra options override base config keys in the sidekiq config" do
      result = builder.with_options(ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_PEER}).sidekiq
      expect(result).to include(ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_PEER})
    end

    it "extra options override base config keys in the cache config" do
      result = builder.with_options(ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_PEER}).cache
      expect(result).to include(ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_PEER})
    end
  end

  describe ".cache_enabled?" do
    subject(:result) { described_class.cache_enabled? }

    context "when neither LAGO_REDIS_CACHE_URL nor LAGO_REDIS_CACHE_SENTINELS is set" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it { is_expected.to be(false) }
    end

    context "when only LAGO_REDIS_CACHE_URL is set" do
      before do
        ENV["LAGO_REDIS_CACHE_URL"] = "redis://cache:6379"
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it { is_expected.to be(true) }
    end

    context "when only LAGO_REDIS_CACHE_SENTINELS is set" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel:26379"
      end

      it { is_expected.to be(true) }
    end

    context "when both LAGO_REDIS_CACHE_URL and LAGO_REDIS_CACHE_SENTINELS are set" do
      before do
        ENV["LAGO_REDIS_CACHE_URL"] = "redis://cache:6379"
        ENV["LAGO_REDIS_CACHE_SENTINELS"] = "cache-sentinel:26379"
      end

      it { is_expected.to be(true) }
    end

    context "when LAGO_REDIS_CACHE_URL is set to an empty string" do
      before do
        ENV["LAGO_REDIS_CACHE_URL"] = ""
        ENV.delete("LAGO_REDIS_CACHE_SENTINELS")
      end

      it { is_expected.to be(false) }
    end

    context "when LAGO_REDIS_CACHE_SENTINELS is set to an empty string" do
      before do
        ENV.delete("LAGO_REDIS_CACHE_URL")
        ENV["LAGO_REDIS_CACHE_SENTINELS"] = ""
      end

      it { is_expected.to be(false) }
    end
  end
end
