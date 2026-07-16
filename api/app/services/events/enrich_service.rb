# frozen_string_literal: true

module Events
  class EnrichService < BaseService
    Result = BaseResult[:enriched_events]

    def initialize(event:, subscription:, billable_metric:, charges_and_filters:, persist: true)
      @event = event
      @subscription = subscription
      @billable_metric = billable_metric
      @charges_and_filters = charges_and_filters
      @persist = persist

      super
    end

    def call
      enriched_event = init_enriched_event

      EnrichedEvent.transaction do
        result.enriched_events = charges_and_filters.map do |charge, filter|
          ev = enriched_event.dup
          ev.charge_id = charge.id

          ev.charge_filter_id = filter&.id
          ev.grouped_by = format_grouped_by(filter&.pricing_group_keys.presence || charge.pricing_group_keys)

          if charge.accepts_target_wallet? && event.properties[Charge::EVENT_TARGET_WALLET_CODE].present?
            ev.target_wallet_code = event.properties[Charge::EVENT_TARGET_WALLET_CODE]
            ev.grouped_by[Charge::EVENT_TARGET_WALLET_CODE] = event.properties[Charge::EVENT_TARGET_WALLET_CODE]
          end

          ev.save! if persist
          ev
        end
      end

      result
    end

    private

    attr_reader :event, :subscription, :billable_metric, :charges_and_filters, :persist

    def init_enriched_event
      enriched_event = EnrichedEvent.new
      enriched_event.event_id = event.id
      enriched_event.organization_id = event.organization_id
      enriched_event.code = event.code
      enriched_event.transaction_id = event.transaction_id
      enriched_event.timestamp = event.timestamp

      enriched_event.external_subscription_id = subscription.external_id
      enriched_event.subscription_id = subscription.id
      enriched_event.plan_id = subscription.plan_id

      enriched_event.enriched_at = Time.current
      enriched_event.precise_total_amount_cents = event.precise_total_amount_cents
      enriched_event.value = (event.properties || {})[billable_metric.field_name] || 0
      enriched_event.value = 1 if billable_metric.count_agg?

      # NOTE: We might not be able to parse the value as a decimal, it will then fall back to 0
      #       The behavior is aligned with the Clickhouse implementation but differs
      #       a bit from the current PG one where we explicitly filter events with invalid values
      enriched_event.decimal_value = decimal_value(enriched_event.value)

      if billable_metric.unique_count_agg?
        operation_type = (event.properties || {})["operation_type"] || "add"
        enriched_event.operation_type = operation_type if BillableMetric::UNIQUE_COUNT_OPERATION_TYPES.include?(operation_type)
      end

      enriched_event
    end

    def format_grouped_by(pricing_group_keys)
      return {} if pricing_group_keys.blank?

      pricing_group_keys.sort.index_with { event.properties[it] }
    end

    def decimal_value(value)
      BigDecimal(value.to_s)
    rescue ArgumentError
      BigDecimal(0)
    end
  end
end
