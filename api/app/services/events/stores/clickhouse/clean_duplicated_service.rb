# frozen_string_literal: true

module Events
  module Stores
    module Clickhouse
      class CleanDuplicatedService < BaseService
        Result = BaseResult

        def initialize(subscription:, timestamp: Time.current)
          @subscription = subscription
          @timestamp = timestamp
          super
        end

        def call
          remove_duplicated_events
          Subscriptions::ChargeCacheService.expire_for_subscription(subscription)

          result
        end

        private

        attr_reader :subscription, :timestamp

        delegate :organization, to: :subscription

        def boundaries
          return @boundaries if @boundaries.present?

          date_service = Subscriptions::DatesService.new_instance(
            subscription,
            timestamp,
            current_usage: true
          )

          @boundaries = BillingPeriodBoundaries.new(
            from_datetime: date_service.from_datetime,
            to_datetime: date_service.to_datetime,
            charges_from_datetime: date_service.charges_from_datetime,
            charges_to_datetime: date_service.charges_to_datetime,
            issuing_date: date_service.next_end_of_period,
            charges_duration: date_service.charges_duration_in_days,
            timestamp:
          )
        end

        def duplicated_events
          ::Clickhouse::EventsEnriched
            .where(organization_id: organization.id)
            .where(external_subscription_id: subscription.external_id)
            .where(timestamp: boundaries.charges_from_datetime...boundaries.charges_to_datetime)
            .group(:transaction_id, :timestamp, :code)
            .having("count() > 1")
            .pluck(:transaction_id, :timestamp, :code)
        end

        def remove_duplicated_events
          duplicates = duplicated_events.to_a
          return if duplicates.empty?

          duplicates.each do |transaction_id, event_timestamp, code|
            # Fetch all enriched_at timestamps for the duplicated events
            enriched_at = ::Clickhouse::EventsEnriched
              .where(organization_id: organization.id)
              .where(external_subscription_id: subscription.external_id)
              .where(timestamp: event_timestamp)
              .where(transaction_id: transaction_id)
              .where(code: code)
              .order(enriched_at: :desc)
              .pluck(:enriched_at)

            ::Clickhouse::EventsEnriched
              .where(organization_id: organization.id)
              .where(external_subscription_id: subscription.external_id)
              .where(timestamp: event_timestamp)
              .where(transaction_id: transaction_id)
              .where(code: code)
              .where(enriched_at: enriched_at[1..])
              .delete_all
          end
        end
      end
    end
  end
end
