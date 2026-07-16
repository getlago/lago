# frozen_string_literal: true

module Subscriptions
  class ActivateAllPendingService < BaseService
    Result = BaseResult

    def initialize(timestamp:)
      @timestamp = Time.zone.at(timestamp)

      super
    end

    def call
      Subscription
        .joins(customer: :billing_entity)
        .pending
        .where(previous_subscription: nil)
        .where(
          "DATE(subscriptions.subscription_at#{at_time_zone}) <= " \
          "DATE(?#{at_time_zone})",
          timestamp
        )
        .find_each do |subscription|
          ActivateService.call!(subscription:, timestamp:)
        end

      result
    end

    private

    attr_reader :timestamp
  end
end
