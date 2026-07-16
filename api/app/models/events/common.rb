# frozen_string_literal: true

module Events
  Common = Struct.new(
    :id,
    :organization_id,
    :transaction_id,
    :external_subscription_id,
    :timestamp,
    :code,
    :properties,
    :precise_total_amount_cents,
    :persisted,
    keyword_init: true
  ) do
    def initialize(**args)
      super
      self[:persisted] = true unless args.key?(:persisted)
    end

    def event_id
      id || transaction_id
    end

    def organization
      @organization ||= Organization.find_by(id: organization_id)
    end

    def billable_metric
      @billable_metric ||= organization.billable_metrics.find_by(code: code)
    end

    def subscription
      return @subscription if defined? @subscription

      @subscription = organization
        .subscriptions
        .where(external_id: external_subscription_id)
        .where("date_trunc('millisecond', started_at::timestamp) <= ?::timestamp", timestamp)
        .where(
          "terminated_at IS NULL OR date_trunc('millisecond', terminated_at::timestamp) >= ?",
          timestamp
        )
        .order("terminated_at DESC NULLS FIRST, started_at DESC")
        .first
    end

    def as_json
      super.tap do |j|
        j["timestamp"] = timestamp.to_f
        j["timestamp_with_precision"] = timestamp.iso8601(9)
      end
    end

    def self.timestamp_from_source(source)
      timestamp = Time.zone.parse(source["timestamp_with_precision"])

      if timestamp.present?
        return timestamp
      end

      Time.zone.at(source["timestamp"].to_f)
    rescue TypeError, ArgumentError
      Time.zone.at(source["timestamp"].to_f)
    end
  end
end
