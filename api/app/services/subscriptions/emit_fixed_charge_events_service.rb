# frozen_string_literal: true

module Subscriptions
  class EmitFixedChargeEventsService < BaseService
    Result = BaseResult

    def initialize(subscriptions:, timestamp: Time.current)
      @subscriptions = subscriptions
      @timestamp = timestamp
      super
    end

    def call
      events_attributes = []

      subscriptions.each do |subscription|
        emitted_fixed_charge_ids = already_emitted_fixed_charge_ids(subscription)

        subscription.fixed_charges.find_each do |fixed_charge|
          next if emitted_fixed_charge_ids.include?(fixed_charge.id)

          events_attributes << {
            organization_id: subscription.organization_id,
            subscription_id: subscription.id,
            fixed_charge_id: fixed_charge.id,
            units: fixed_charge.effective_units_for(subscription),
            timestamp:
          }
        end
      end

      ::FixedChargeEvents::BulkCreateService.call!(events_attributes:)

      result
    end

    private

    attr_reader :subscriptions, :timestamp

    def applicable_timezone
      subscriptions.first.customer.applicable_timezone
    end

    def already_emitted_fixed_charge_ids(subscription)
      return Set.new unless timestamp

      FixedChargeEvent
        .where(subscription:)
        .where(
          "DATE(fixed_charge_events.timestamp AT TIME ZONE ?) = DATE(? AT TIME ZONE ?)",
          applicable_timezone, timestamp, applicable_timezone
        )
        .pluck(:fixed_charge_id)
        .to_set
    end
  end
end
