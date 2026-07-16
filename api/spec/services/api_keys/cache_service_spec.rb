# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiKeys::CacheService, cache: :redis do
  subject(:cache_service) { described_class.new(auth_token, with_cache:) }

  let(:auth_token) { "token" }
  let(:with_cache) { false }

  describe "#cache_key" do
    it "returns the cache key" do
      expect(cache_service.cache_key).to eq("api_key/#{described_class::CACHE_KEY_VERSION}/token")
    end
  end

  describe "#expire_cache" do
    it "deletes the cached value" do
      allow(Rails.cache).to receive(:delete).with(cache_service.cache_key)

      cache_service.expire_cache

      expect(Rails.cache).to have_received(:delete).with(cache_service.cache_key)
    end
  end

  describe "#expire_all_cache" do
    let(:organization) { create(:organization, api_keys:) }
    let(:api_keys) { create_list(:api_key, 3) }

    it "deletes all cached values" do
      allow(Rails.cache).to receive(:delete)

      described_class.expire_all_cache(organization)

      expect(Rails.cache).to have_received(:delete).exactly(3).times
    end
  end

  describe "#call" do
    let(:organization) { create(:organization, api_keys: [api_key]) }
    let(:api_key) { create(:api_key) }
    let(:auth_token) { api_key.value }

    before { organization }

    it "returns the api_key and the organization" do
      expect(cache_service.call).to eq([api_key, organization])
    end

    context "when cache is enabled" do
      let(:with_cache) { true }

      before { Rails.cache.clear }

      it "returns the api_key and the organization and create the cache" do
        expect(cache_service.call).to eq([api_key, organization])

        expect(Rails.cache.read(cache_service.cache_key)).to be_present
      end

      context "when cache exists" do
        before { cache_service.call }

        it "returns the api_key and the organization" do
          expect(cache_service.call).to eq([api_key, organization])
        end
      end

      context "when cached value is expired" do
        let(:api_key) { create(:api_key, expires_at: Time.current - 10.minutes) }

        before do
          Rails.cache.write(cache_service.cache_key, {
            api_key: api_key.attributes,
            organization: organization.attributes
          }.to_json)
        end

        it "does not return the cache key and organization" do
          expect(cache_service.call).to eq([nil, nil])
        end
      end
    end
  end
end
