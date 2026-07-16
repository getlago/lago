# frozen_string_literal: true

module Subscriptions
  class ChargeCacheMiddleware
    EMPTY_ARRAY = [].freeze

    def initialize(subscription:, charge:, to_datetime:, cache: true)
      @subscription = subscription
      @charge = charge
      @to_datetime = to_datetime
      @cache = cache
    end

    def call(charge_filter:)
      return yield unless cache

      json = Subscriptions::ChargeCacheService.call(subscription:, charge:, charge_filter:, expires_in: cache_expiration) do
        yield
          .map do |fee|
            fee.attributes.merge(
              "pricing_unit_usage" => fee.pricing_unit_usage&.attributes,
              "presentation_breakdowns" => fee.presentation_breakdowns.map(&:attributes)
            )
          end
          .to_json
      end

      JSON.parse(json).map do |j|
        pricing_unit_usage = if j["pricing_unit_usage"].present?
          PricingUnitUsage.new(j["pricing_unit_usage"].slice(*PricingUnitUsage.column_names))
        end

        fee = Fee.new(
          **j.slice(*Fee.column_names),
          pricing_unit_usage:
        )

        j.fetch("presentation_breakdowns", EMPTY_ARRAY).each do |breakdown|
          fee.presentation_breakdowns.build(
            breakdown.slice(*PresentationBreakdown.column_names)
          )
        end

        fee
      end
    end

    private

    attr_reader :subscription, :charge, :to_datetime, :cache

    def cache_expiration
      return 0 unless to_datetime

      [(to_datetime - Time.current).to_i.seconds, 0].max
    end
  end
end
