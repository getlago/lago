# frozen_string_literal: true

module ChargeFilters
  class EventMatchingService < BaseService
    Result = BaseResult[:matching_charge_filters, :charge_filter]

    def initialize(charge:, event:)
      @charge = charge
      @event = event

      super
    end

    def call
      # NOTE: Find all filters matching event properties
      matching_filters = filters.select do |filter|
        filter.to_h.all? do |key, values|
          applicable_event_properties.key?(key) &&
            (applicable_event_properties[key].to_s.in?(values) || values == [ChargeFilterValue::ALL_FILTER_VALUES])
        end
      end

      # NOTE: An event could match multiple filters. Expose the full list so callers
      #       that need every candidate (e.g. usage pre-filtering) can let the
      #       aggregation cascade assign the event to the most specific one.
      result.matching_charge_filters = matching_filters

      # NOTE: When a single filter must be picked, take the one matching the most properties
      result.charge_filter = matching_filters.max_by { |filter| filter.to_h.keys.size }
      result
    end

    private

    attr_reader :charge, :event

    # NOTE: Exclude event properties not matching a billable metric filter
    def applicable_event_properties
      @applicable_event_properties ||= event.properties.slice(*billable_metric_filter_keys)
    end

    # NOTE: when filters are already pre-loaded (e.g. usage pre-filtering), reuse the
    #       loaded association to avoid a query. Otherwise pluck the keys directly.
    def billable_metric_filter_keys
      billable_metric = charge.billable_metric

      return billable_metric.filters.map(&:key) if billable_metric.association_cached?(:filters)

      billable_metric.filters.pluck(:key)
    end

    def filters
      # NOTE: when called from the cache invalidator, filters are already pre-loaded,
      #       we just return the preloaded list to avoid N+1 queries
      return charge.filters if charge.association_cached?(:filters)

      charge.filters.includes(values: :billable_metric_filter)
    end
  end
end
