# frozen_string_literal: true

module Events
  class BillingPeriodFilterService < BaseService
    Result = BaseResult[:charges]

    def initialize(subscription:, boundaries:)
      @subscription = subscription
      @boundaries = boundaries
      super
    end

    # Return the list of charges and filters that will be used in the billing or usage computation
    # The result will be a hash where the key is the charge id and the value is an array of filter ids
    # filter ids could also include "nil" as a default filter
    def call
      result.charges = deduplicate_filters(charges_and_filters)
      result
    end

    private

    attr_reader :subscription, :boundaries

    delegate :plan, :organization, to: :subscription

    def event_store
      @event_store ||= Events::Stores::StoreFactory.new_instance(
        organization: organization,
        subscription:,
        boundaries: {
          from_datetime: boundaries.charges_from_datetime,
          to_datetime: boundaries.charges_to_datetime
        }
      )
    end

    def plan_codes
      @plan_codes ||= plan.billable_metrics.distinct.pluck(:code)
    end

    def charges_and_filters
      return charges_and_filters_from_events unless organization.pre_filter_events?

      charges_and_filters_from_pre_enriched_events
    end

    # Return the list of all charges and filters that received usage in the period
    # It also includes the recurring charges and filters
    # The result will be a hash where the key is the charge id and the value is an array of filter ids
    # filter ids also include "nil" as a default filter
    #
    # For non-recurring charges, the exact filters are resolved by matching the distinct
    # property combinations actually present in the events against the charge filters, so
    # only the filters that received usage are returned.
    def charges_and_filters_from_events
      combinations = event_store.distinct_codes_and_property_combinations(
        codes: plan_codes,
        filter_keys: billable_metric_filter_keys
      )

      combinations_by_code = combinations
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last) }

      # Recurring charges must always be billed as usage carries over from previous periods
      result = recurring_event_charges_and_filters

      non_recurring_charges_with_events(combinations_by_code.keys).each do |charge|
        code = charge.billable_metric.code

        combinations_by_code[code].each do |properties|
          event = ::Event.new(code:, properties:)
          matching = ChargeFilters::EventMatchingService.call(charge:, event:).matching_charge_filters

          # No filter matches: the usage falls into the default bucket.
          # Otherwise include every matching filter and let the aggregation cascade
          # assign the event to the most specific one (the others aggregate to zero).
          if matching.empty?
            result[charge.id] << nil
          else
            matching.each { |filter| result[charge.id] << filter.id }
          end
        end
      end

      result
    end

    # Recurring charges and all their filters (including the default bucket).
    # They are always returned, even without events, as usage carries over.
    def recurring_event_charges_and_filters
      plan.charges.joins(:billable_metric).left_joins(:filters)
        .where(billable_metrics: {recurring: true})
        .group("charges.id, charge_filters.id")
        .pluck("charges.id", "charge_filters.id")
        .then { group_by_charge_id(it) }
        .then { add_default_filter(it) }
    end

    # Non-recurring charges of the plan whose billable metric received events in the period
    def non_recurring_charges_with_events(codes)
      plan.charges
        .joins(:billable_metric)
        .where(billable_metrics: {code: codes, recurring: false})
        .includes(billable_metric: :filters, filters: {values: :billable_metric_filter})
    end

    # Union of every filter key defined across the plan billable metrics
    def billable_metric_filter_keys
      @billable_metric_filter_keys ||= BillableMetricFilter
        .where(billable_metric_id: plan.billable_metrics.select(:id))
        .distinct
        .pluck(:key)
    end

    # Return the list of charges and filters that matches the event pre enriched in clickhouse or Postgres for the period
    # It also includes the recurring charges and filters
    # The result will be a hash where the key is the charge id and the value is an array of filter ids
    # filter ids also include "nil" as a default filter when applicable
    def charges_and_filters_from_pre_enriched_events
      values = event_store.distinct_charges_and_filters(codes: plan_codes)

      charge_filter_ids = values.map(&:last).reject(&:blank?)
      charge_ids = values.map(&:first).uniq

      existing_charge_ids = plan.charges.where(id: charge_ids).pluck(:id)
      existing_charge_filters = fetch_existing_filters(charge_filter_ids)

      result = recurring_charges_and_filters

      values.each do |charge_id, filter_id|
        # Charge has been removed from the plan
        next unless existing_charge_ids.include?(charge_id)

        # Charge has no filters or only default bucket received usage in the period
        if filter_id.blank?
          result[charge_id] << nil
          next
        end

        # Keep only existing filters
        next unless existing_charge_filters.include?(filter_id)
        result[charge_id] << filter_id
      end

      result
    end

    def recurring_charges_and_filters
      # First period: no previous usage exists, events from current period are enough
      return Hash.new { |h, k| h[k] = [] } if subscription.started_at >= boundaries.charges_from_datetime

      # If the subscription was upgraded, use the upgrade chain to filter recurring charges
      return recurring_charges_and_filters_from_upgrade_chain if subscription.previous_subscription_id.present?

      # Use previous fees to filter the recurring charges with existing usage
      recurring_charges_and_filters_from_previous_fees
    end

    def recurring_charges_and_filters_from_previous_fees
      pairs = current_subscription_recurring_fees

      return Hash.new { |h, k| h[k] = [] } if pairs.empty?

      filter_ids = pairs.map(&:last).compact
      if filter_ids.any?
        existing_filter_ids = fetch_existing_filters(filter_ids)
        pairs = pairs.select { |_, f_id| f_id.nil? || existing_filter_ids.include?(f_id) }
      end

      pairs.then { group_by_charge_id(it) }
    end

    def recurring_charges_and_filters_from_upgrade_chain
      # First, let's fetch fees from the current subscription created before the current period
      result = current_subscription_recurring_fees
        .then { group_by_charge_id(it) }

      # Then, include all filters for charges whose billable metric had previous usage
      previous_bm_ids = previous_subscriptions_billable_metric_ids
      return result if previous_bm_ids.empty?

      current_recurring_charges.each do |charge|
        next unless previous_bm_ids.include?(charge.billable_metric_id)

        filter_ids = charge.filters.map(&:id)
        result[charge.id] = (result[charge.id] + filter_ids + [nil]).uniq
      end
      result
    end

    # Fetches all recurring charges for the current plan
    def current_recurring_charges
      @current_recurring_charges ||= plan.charges
        .joins(:billable_metric)
        .where(billable_metrics: {recurring: true})
        .includes(:filters)
        .to_a
    end

    # Fetches all recurring billable metrics IDs from previous subscriptions,
    # still used in the current plan
    def previous_subscriptions_billable_metric_ids
      previous_sub_ids = collect_previous_subscription_ids
      return Set.new if previous_sub_ids.empty?

      bm_ids = current_recurring_charges.map(&:billable_metric_id)
      return Set.new if bm_ids.empty?

      Fee.where(subscription_id: previous_sub_ids, fee_type: :charge)
        .joins(charge: :billable_metric)
        .where(billable_metrics: {id: bm_ids})
        .positive_units
        .distinct
        .pluck(:billable_metric_id)
        .to_set
    end

    # Fetches all terminated subscription IDs sharing the same external_id
    def collect_previous_subscription_ids
      organization.subscriptions
        .terminated
        .where(external_id: subscription.external_id, customer_id: subscription.customer_id)
        .where.not(id: subscription.id)
        .pluck(:id)
    end

    # Fetchs all recurring fees created for the current subscription before the current billing period
    def current_subscription_recurring_fees
      Fee.where(subscription_id: subscription.id, fee_type: :charge)
        .joins(invoice: :invoice_subscriptions)
        .where("invoice_subscriptions.subscription_id = fees.subscription_id")
        .where("invoice_subscriptions.charges_from_datetime < ?", boundaries.charges_from_datetime)
        .joins(charge: :billable_metric)
        .where(charges: {plan_id: plan.id, deleted_at: nil})
        .where(billable_metrics: {recurring: true})
        .positive_units
        .distinct
        .pluck(:charge_id, :charge_filter_id)
    end

    # Group all charges and filters by charge_id
    def group_by_charge_id(rows)
      rows.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(charge_id, filter_id), hash|
        hash[charge_id] << filter_id
      end
    end

    # Include "default" bucket for recurring charges
    def add_default_filter(charges_and_filters)
      charges_and_filters.each_value { it << nil }
      charges_and_filters
    end

    # Make sure all filters are unique for each charge
    def deduplicate_filters(charges_and_filters)
      charges_and_filters.transform_values(&:uniq)
    end

    def fetch_existing_filters(charge_filter_ids)
      plan.charges.joins(:filters)
        .where(charge_filters: {id: charge_filter_ids})
        .pluck("charge_filters.id")
    end
  end
end
