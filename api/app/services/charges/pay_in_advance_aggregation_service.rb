# frozen_string_literal: true

module Charges
  class PayInAdvanceAggregationService < BaseService
    def initialize(charge:, boundaries:, properties:, event:, charge_filter: nil)
      @charge = charge
      @boundaries = boundaries
      @properties = properties
      @event = event
      @charge_filter = charge_filter

      super
    end

    def call
      aggregator = BillableMetrics::AggregationFactory.new_instance(
        charge:,
        subscription:,
        boundaries: {
          from_datetime: boundaries.charges_from_datetime,
          to_datetime: boundaries.charges_to_datetime,
          charges_duration: boundaries.charges_duration,
          max_timestamp: event.timestamp
        },
        filters: aggregation_filters
      )

      aggregator.aggregate(options: aggregation_options)
    end

    private

    attr_reader :charge, :boundaries, :properties, :event, :charge_filter

    delegate :subscription, to: :event
    delegate :billable_metric, to: :charge

    def aggregation_options
      {
        free_units_per_events: properties["free_units_per_events"].to_i,
        free_units_per_total_aggregation: BigDecimal(properties["free_units_per_total_aggregation"] || 0)
      }
    end

    def aggregation_filters
      filters = {event:, charge_id: charge.id}

      model = charge_filter.presence || charge
      grouped_by_values = model.pricing_group_keys&.index_with { event.properties[it] } || {}
      if charge.accepts_target_wallet && event.properties["target_wallet_code"].present?
        grouped_by_values["target_wallet_code"] = event.properties["target_wallet_code"]
      end
      filters[:grouped_by_values] = grouped_by_values if grouped_by_values.present?

      presentation_group_keys_values = charge.presentation_group_keys_values
      filters[:presentation_by] = presentation_group_keys_values if presentation_group_keys_values.present?

      if charge_filter.present?
        result = ChargeFilters::MatchingAndIgnoredService.call(charge:, filter: charge_filter)
        filters[:charge_filter] = charge_filter if charge_filter.persisted?
        filters[:matching_filters] = result.matching_filters
        filters[:ignored_filters] = result.ignored_filters
      end

      filters
    end
  end
end
