# frozen_string_literal: true

module Queries
  class EventsQueryFiltersContract < Dry::Validation::Contract
    params do
      optional(:code).maybe(:string)
      optional(:external_subscription_id).maybe(:string)
      optional(:timestamp_from_started_at).value(:"coercible.string", included_in?: %w[true false])
      optional(:timestamp_from)
      optional(:timestamp_to)
      optional(:enriched).value(:bool)
    end

    rule("timestamp_from_started_at", "timestamp_from") do
      if ActiveModel::Type::Boolean.new.cast(values["timestamp_from_started_at"]) && values["timestamp_from"].present?
        key(:timestamp_from).failure("cannot be used with timestamp_from_started_at")
      end
    end

    rule("timestamp_from_started_at", "external_subscription_id") do
      if ActiveModel::Type::Boolean.new.cast(values["timestamp_from_started_at"]) && values["external_subscription_id"].blank?
        key(:external_subscription_id).failure("required with timestamp_from_started_at")
      end
    end
  end
end
