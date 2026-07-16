# frozen_string_literal: true

require "rails_helper"

RSpec.describe CacheService do
  let(:test_cache_service_class) do
    Class.new(described_class) do
      def initialize(key_suffix = nil, expires_in: nil)
        @key_suffix = key_suffix
        super(nil, expires_in: expires_in)
      end

      def cache_key
        "test_cache_service:#{@key_suffix}"
      end
    end
  end

  describe "#call" do
    let(:cache_service) { test_cache_service_class.new("test", expires_in: nil) }
    let(:cache_key) { cache_service.cache_key }
    let(:cached_value) { "cached_value" }
    let(:new_value) { "new_value" }

    context "when cache exists" do
      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(cached_value)
      end

      it "returns cached value without calling the block" do
        block_called = false
        result = cache_service.call {
          block_called = true
          new_value
        }

        expect(result).to eq(cached_value)
        expect(block_called).to be false
      end
    end

    context "when cache does not exist" do
      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Rails.cache).to receive(:write)
      end

      it "calls the block and caches the result" do
        result = cache_service.call { new_value }

        expect(result).to eq(new_value)
        expect(Rails.cache).to have_received(:write).with(cache_key, new_value, expires_in: nil)
      end
    end

    context "when expires_in is zero" do
      let(:cache_service) { test_cache_service_class.new("test", expires_in: 0) }

      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil)
        allow(Rails.cache).to receive(:write)
      end

      it "calls the block but does not cache the result" do
        result = cache_service.call { new_value }

        expect(result).to eq(new_value)
        expect(Rails.cache).not_to have_received(:write)
      end
    end
  end

  describe "#expire_cache" do
    let(:cache_service) { test_cache_service_class.new("test") }
    let(:cache_key) { cache_service.cache_key }

    before do
      allow(Rails.cache).to receive(:delete)
    end

    it "deletes the cache" do
      cache_service.expire_cache

      expect(Rails.cache).to have_received(:delete).with(cache_key)
    end
  end

  describe ".expire_cache" do
    it "creates an instance and calls expire_cache" do
      test_class = test_cache_service_class
      instance = instance_double(test_class)

      allow(test_class).to receive(:new).with("test").and_return(instance)
      allow(instance).to receive(:expire_cache)

      test_class.expire_cache("test")

      expect(instance).to have_received(:expire_cache)
    end
  end

  describe "#cache_key" do
    it "raises NotImplementedError when called on the base class" do
      expect { described_class.new.cache_key }.to raise_error(NotImplementedError)
    end
  end
end
