# frozen_string_literal: true

module Fees
  class CreatePayInAdvanceService < BaseService
    Result = BaseResult[:fees, :invoice_id]

    def initialize(charge:, event:, billing_at: nil, estimate: false)
      @charge = charge
      @event = Events::CommonFactory.new_instance(source: event)
      @billing_at = billing_at || @event.timestamp

      @estimate = estimate
      raise ArgumentError, "estimate must be true if event if not persisted" if !@event.persisted && !estimate

      super
    end

    def call
      fees = []

      ActiveRecord::Base.transaction(**isolation_mode) do
        fees << if charge.filters.any?
          init_charge_filter_fee
        else
          init_fee(properties:)
        end
      end

      ActiveRecord::Base.transaction do
        result.fees = persist_fees(fees.compact)

        if !charge.invoiceable? && customer_provider_taxation?
          Fees::ApplyProviderTaxesToStandaloneFeesService.call!(
            customer:, fees: result.fees, currency: subscription.plan.amount_currency
          )
        end
      end

      deliver_webhooks

      result
    rescue BaseService::FailedResult => e
      result.fail_with_error!(e)
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :charge, :event, :billing_at, :estimate

    delegate :billable_metric, to: :charge
    delegate :subscription, to: :event

    def filter
      @filter ||= ChargeFilters::EventMatchingService.call(charge:, event:).charge_filter
    end

    def init_fee(properties:, charge_filter: nil)
      aggregation_result = aggregate(properties:, charge_filter:)
      cache_aggregation_result(aggregation_result:, charge_filter:)

      charge_model_result = apply_charge_model(aggregation_result:, properties:)

      if charge.applied_pricing_unit
        pricing_unit_usage = PricingUnitUsage.build_from_fiat_amounts(
          amount: charge_model_result.amount / charge.pricing_unit.subunit_to_unit.to_d,
          unit_amount: charge_model_result.unit_amount,
          applied_pricing_unit: charge.applied_pricing_unit
        )

        amount_cents, precise_amount_cents, unit_amount_cents, precise_unit_amount = pricing_unit_usage
          .to_fiat_currency_cents(subscription.plan.amount.currency)
          .values_at(:amount_cents, :precise_amount_cents, :unit_amount_cents, :precise_unit_amount)
      else
        pricing_unit_usage = nil
        amount_cents = charge_model_result.amount
        precise_amount_cents = charge_model_result.precise_amount
        unit_amount_cents = charge_model_result.unit_amount * subscription.plan.amount.currency.subunit_to_unit
        precise_unit_amount = charge_model_result.unit_amount
      end

      fee = Fee.new(
        subscription:,
        charge:,
        organization_id: customer.organization_id,
        billing_entity_id: customer.billing_entity_id,
        amount_cents:,
        precise_amount_cents:,
        amount_currency: subscription.plan.amount_currency,
        fee_type: :charge,
        invoiceable: charge,
        units: charge_model_result.units,
        total_aggregated_units: charge_model_result.units,
        properties: boundaries.to_h,
        events_count: charge_model_result.count,
        charge_filter_id: charge_filter&.id,
        pay_in_advance_event_id: event.id,
        pay_in_advance_event_transaction_id: event.transaction_id,
        payment_status: :pending,
        pay_in_advance: true,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.to_d,
        unit_amount_cents:,
        precise_unit_amount:,
        grouped_by: format_grouped_by,
        amount_details: charge_model_result.amount_details || {},
        pricing_unit_usage:
      )

      build_breakdowns_for_fee(fee:, presentation_breakdowns: remove_formated_grouped_by_keys(aggregation_result.pay_in_advance_breakdowns))

      fee
    end

    def init_charge_filter_fee
      init_fee(properties:, charge_filter: filter || ChargeFilter.new(charge:))
    end

    def persist_fees(fees)
      fees.map do |fee|
        # Non-invoiceable fees are regrouped later by AdvanceChargesService which
        # aggregates pre-existing fee taxes. They must have taxes applied now because
        # there is no ComputeTaxesAndTotalsService step for them.
        # Provider-taxed customers get taxes via apply_provider_taxes after persist.
        # Invoiceable fees get taxes applied later via ComputeTaxesAndTotalsService.
        if !charge.invoiceable? && !customer_provider_taxation?
          Fees::ApplyTaxesService.call!(fee:)
        end

        fee.save! unless estimate
        fee
      end
    end

    def date_service
      @date_service ||= Subscriptions::DatesService.new_instance(
        subscription,
        billing_at,
        current_usage: true
      )
    end

    def properties
      @properties ||= filter&.properties || charge.properties
    end

    def boundaries
      @boundaries ||= BillingPeriodBoundaries.new(
        from_datetime: date_service.from_datetime,
        to_datetime: date_service.to_datetime,
        charges_from_datetime: date_service.charges_from_datetime,
        charges_to_datetime: date_service.charges_to_datetime,
        charges_duration: date_service.charges_duration_in_days,
        timestamp: billing_at
      )
    end

    def aggregate(properties:, charge_filter: nil)
      Charges::PayInAdvanceAggregationService.call!(
        charge:, boundaries:, properties:, event:, charge_filter:
      )
    end

    def apply_charge_model(aggregation_result:, properties:)
      Charges::ApplyPayInAdvanceChargeModelService.call!(
        charge:, aggregation_result:, properties:
      )
    end

    def deliver_webhooks
      return if estimate

      result.fees.each { |f| SendWebhookJob.perform_later("fee.created", f) }
    end

    def build_breakdowns_for_fee(fee:, presentation_breakdowns:)
      presentation_breakdowns.each do |breakdown|
        fee.presentation_breakdowns.build(
          presentation_by: breakdown[:groups],
          units: breakdown[:value],
          organization_id: charge.organization_id
        )
      end
    end

    def cache_aggregation_result(aggregation_result:, charge_filter:)
      return unless aggregation_result.current_aggregation.present? ||
        aggregation_result.max_aggregation.present? ||
        aggregation_result.max_aggregation_with_proration.present?

      CachedAggregation.create!(
        organization_id: event.organization_id,
        event_transaction_id: event.transaction_id,
        timestamp: billing_at,
        external_subscription_id: event.external_subscription_id,
        charge_id: charge.id,
        charge_filter_id: charge_filter&.id,
        current_aggregation: aggregation_result.current_aggregation,
        current_amount: aggregation_result.current_amount,
        max_aggregation: aggregation_result.max_aggregation,
        max_aggregation_with_proration: aggregation_result.max_aggregation_with_proration,
        grouped_by: format_grouped_by,
        presentation_breakdowns: remove_formated_grouped_by_keys(aggregation_result.breakdowns)
      )
    end

    def remove_formated_grouped_by_keys(breakdowns)
      Array(breakdowns).map { |b| b.merge(groups: b[:groups].except(*format_grouped_by.keys)) }
    end

    def format_grouped_by
      return @format_grouped_by if defined?(@format_grouped_by)

      grouped_by = properties["pricing_group_keys"].presence || properties["grouped_by"] || []
      grouped_by << "target_wallet_code" if charge.accepts_target_wallet && event.properties["target_wallet_code"].present?
      return @format_grouped_by = {} if grouped_by.blank?

      @format_grouped_by = grouped_by.index_with { event.properties[it] }
    end

    def customer
      @customer ||= subscription.customer
    end

    def customer_provider_taxation?
      return @customer_provider_taxation if defined?(@customer_provider_taxation)

      @customer_provider_taxation = customer.tax_customer.present?
    end

    def isolation_mode
      # NOTE: this is only to avoid failure with spec scnearios
      return {} if ActiveRecord::Base.connection.transaction_open?

      {isolation: :repeatable_read}
    end
  end
end
