# frozen_string_literal: true

module DatabaseMigrations
  class BackfillLastReceivedEventOnJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    def perform(organization_id)
      organization = Organization.find(organization_id)

      if organization.clickhouse_events_store?
        process_clickhouse(organization)
      else
        process_postgres(organization)
      end
    end

    def lock_key_arguments
      [arguments]
    end

    private

    def process_postgres(organization)
      organization.subscriptions.active
        .where(last_received_event_on: nil)
        .find_each do |subscription|
          base_scope = Event.where(
            organization_id: organization.id,
            external_subscription_id: subscription.external_id,
            deleted_at: nil
          )

          last_event_date = find_last_event_date(base_scope, subscription.started_at.to_date)
          subscription.update_column(:last_received_event_on, last_event_date) if last_event_date # rubocop:disable Rails/SkipsModelValidations
      end
    end

    def process_clickhouse(organization)
      organization.subscriptions.active
        .where(last_received_event_on: nil)
        .find_each do |subscription|
          last_event_date = Clickhouse::EventsRaw
            .where(organization_id: organization.id, external_subscription_id: subscription.external_id)
            .order(ingested_at: :desc)
            .limit(1)
            .pick(:ingested_at)
            &.to_date

          subscription.update_column(:last_received_event_on, last_event_date) if last_event_date # rubocop:disable Rails/SkipsModelValidations
      end
    end

    def find_last_event_date(base_scope, start_date)
      return nil unless base_scope.where("timestamp >= ?", start_date).exists?

      today = Date.current
      days_active = (today - start_date).to_i

      if days_active > 365
        find_last_event_date_windowed(base_scope, start_date, today)
      else
        find_last_event_date_binary(base_scope, start_date, today)
      end
    end

    def find_last_event_date_binary(base_scope, low, high)
      result = nil
      while low <= high
        mid = low + ((high - low) / 2).days
        if base_scope.where("timestamp >= ?", mid).exists?
          result = mid
          low = mid + 1.day
        else
          high = mid - 1.day
        end
      end
      result
    end

    def find_last_event_date_windowed(base_scope, start_date, today)
      [7, 30, 90, 180, 365, 730, 1500].each do |days|
        window_start = [today - days.days, start_date].max
        next unless base_scope.where("timestamp >= ?", window_start).exists?

        return find_last_event_date_binary(base_scope, window_start, today)
      end
      nil
    end
  end
end
