# frozen_string_literal: true

module Subscriptions
  class ChargeCacheService < CacheService
    CACHE_KEY_VERSION = "1"

    def self.expire_for_subscriptions(subscription_ids)
      Subscription
        .where(id: subscription_ids)
        .preload(plan: {charges: :filters})
        .find_each do |subscription|
          subscription.plan.charges.each do |charge|
            expire_for_subscription_charge(subscription:, charge:)
          end
        end
    end

    def self.expire_for_subscription(subscription)
      expire_for_subscriptions([subscription.id])
    end

    def self.expire_for_subscription_charge(subscription:, charge:)
      charge.filters.each do |filter|
        expire_cache(subscription:, charge:, charge_filter: filter)
      end

      expire_cache(subscription:, charge:)
    end

    def initialize(subscription:, charge:, charge_filter: nil, expires_in: nil)
      @subscription = subscription
      @charge = charge
      @charge_filter = charge_filter

      super(expires_in:)
    end

    # IMPORTANT
    # when making changes here, please make sure to bump the cache key so old values are immediately invalidated!
    def cache_key
      [
        "charge-usage",
        CACHE_KEY_VERSION,
        charge.id,
        subscription.id,
        charge.updated_at.iso8601,
        charge_filter&.id,
        charge_filter&.updated_at&.iso8601
      ].compact.join("/")
    end

    private

    attr_reader :subscription, :charge, :charge_filter
  end
end
