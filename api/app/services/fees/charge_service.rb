# frozen_string_literal: true

module Fees
  class ChargeService < BaseService
    Result = BaseResult[:fees, :cached_aggregations]

    # optional params:
    # | usage_filters - UsageFilters
    #  - context (:current_usage, :invoice_preview, :recurring) - to be moved in usage_filters
    # | results_adjustments - to be implemented as a class to pass the following inside:
    #  - with_zero_units_filters
    #  - calculate_projected_usage
    #  - apply_taxes
    #  - filtered_aggregations
    def initialize(
      invoice:,
      charge:,
      subscription:,
      boundaries:,
      context: nil,
      cache_middleware: nil,
      filtered_aggregations: nil,
      apply_taxes: false,
      calculate_projected_usage: false,
      with_zero_units_filters: true,
      usage_filters: UsageFilters::NONE,
      skip_adjusted_fees: false,
      plan: nil,
      customer: nil
    )
      @invoice = invoice
      @charge = charge
      @subscription = subscription
      @boundaries = boundaries
      @currency = subscription.plan.amount.currency
      @apply_taxes = apply_taxes
      @calculate_projected_usage = calculate_projected_usage
      @with_zero_units_filters = with_zero_units_filters
      @context = context
      @current_usage = context == :current_usage
      @cache_middleware = cache_middleware || Subscriptions::ChargeCacheMiddleware.new(
        subscription:, charge:, to_datetime: boundaries.charges_to_datetime, cache: false
      )

      # Allow the service to ignore events aggregation
      @filtered_aggregations = filtered_aggregations
      @usage_filters = usage_filters
      @skip_adjusted_fees = skip_adjusted_fees

      @plan = plan
      @customer = customer

      super(nil)
    end

    def call
      return result if !current_usage && already_billed?

      init_fees
      return result if current_usage

      if invoice.nil? || !invoice.progressive_billing?
        init_true_up_fee
      end
      return result unless result.success?

      ActiveRecord::Base.transaction do
        result.fees.reject! { |f| !should_persist_fee?(f, result.fees) }
        next if context == :invoice_preview

        result.fees.each do |fee|
          fee.save!

          next unless invoice&.draft? && fee.true_up_parent_fee.nil? && adjusted_fee(
            charge_filter: fee.charge_filter,
            grouped_by: fee.grouped_by
          )

          adjusted_fee(charge_filter: fee.charge_filter, grouped_by: fee.grouped_by).update!(fee:)
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :invoice, :charge, :subscription, :boundaries, :context, :current_usage, :currency, :cache_middleware,
      :filtered_aggregations, :apply_taxes, :calculate_projected_usage, :with_zero_units_filters, :usage_filters

    delegate :billable_metric, to: :charge
    delegate :organization, to: :subscription
    delegate :plan, to: :subscription

    def init_fees
      result.fees = []

      return init_charge_fees(properties: charge.properties) unless charge.filters.any?

      # NOTE: Create a fee for each filters defined on the charge.
      charge.filters.each do |charge_filter|
        init_charge_fees(properties: charge_filter.properties, charge_filter:)
      end

      # NOTE: Create a fee for events not matching any filters.
      charge_filter = ChargeFilter.new(charge:, properties: {"pricing_group_keys" => charge.pricing_group_keys})
      init_charge_fees(properties: charge.properties, charge_filter:)
    end

    def init_charge_fees(properties:, charge_filter: nil)
      fees = cache_middleware.call(charge_filter:) do
        aggregation_result = aggregator(charge_filter:).aggregate(options: options(properties))

        unless aggregation_result.success?
          result.fail_with_error!(aggregation_result.error)
          return []
        end

        charge_model_result = apply_charge_model(aggregation_result:, properties:)
        unless charge_model_result.success?
          result.fail_with_error!(charge_model_result.error)
          return []
        end

        breakdowns_by_group = breakdowns_by_grouped_by(aggregation_result.breakdowns, charge_model_result)

        if billable_metric.recurring?
          persist_recurring_value(aggregation_result.aggregations || [aggregation_result], charge_filter, breakdowns_by_group)
        end

        charge_fees = fees_from_charge_model_result(
          charge_model_result,
          properties:,
          charge_filter:,
          breakdowns_by_group:
        )

        filter_non_persistable_fees_for_caching(charge_fees)
      end

      if fees.empty? && skip_caching_of_non_persistable_fee?
        fees = hydrate_non_persistable_fees(properties:, charge_filter:)
      end

      # Preserve preloaded associations on all fees (including cached ones) to avoid N+1 queries
      fees.each do |fee|
        fee.association(:billable_metric).target = billable_metric
        fee.association(:charge_filter).target = charge_filter if charge_filter&.id
        fee.association(:charge).target = charge
      end

      result.fees.concat(fees.compact)
    end

    def skip_caching_of_non_persistable_fee?
      current_usage
    end

    def hydrate_non_persistable_fees(properties:, charge_filter:)
      zero_aggregation = aggregator(charge_filter:).empty_results

      charge_model_result = ChargeModels::Factory.new_instance(
        chargeable: charge,
        aggregation_result: zero_aggregation,
        properties:,
        period_ratio: calculate_period_ratio,
        calculate_projected_usage:
      ).apply

      fees_from_charge_model_result(charge_model_result, properties:, charge_filter:, breakdowns_by_group: {})
    end

    def fees_from_charge_model_result(charge_model_result, properties:, charge_filter:, breakdowns_by_group:)
      charge_model_result.grouped_results.map do |amount_result|
        # TODO: check if this is still needed as we now skip certain zero units fees
        next if current_usage && charge_filter && amount_result.units.zero? && !with_zero_units_filters

        adjusted = applicable_adjusted_fee(amount_result:, charge_filter:)
        fee = init_fee(amount_result, properties:, charge_filter:, adjusted:)
        next if fee.nil?

        if adjusted.nil? || amount_result.units == fee.units
          build_breakdowns_for_fee(fee:, breakdowns_by_group:)
        end

        fee
      end.compact
    end

    def applicable_adjusted_fee(amount_result:, charge_filter:)
      return nil if current_usage
      return nil unless invoice&.draft?

      adjusted = adjusted_fee(charge_filter:, grouped_by: amount_result.grouped_by)
      return nil if adjusted.nil? || adjusted.adjusted_display_name?

      adjusted
    end

    def build_breakdowns_for_fee(fee:, breakdowns_by_group:)
      grouped_by = fee.grouped_by

      (breakdowns_by_group[grouped_by] || []).map do |breakdown|
        fee.presentation_breakdowns.build(
          presentation_by: breakdown[:groups],
          units: breakdown[:value],
          organization_id: charge.organization_id
        )
      end
    end

    def breakdowns_by_grouped_by(breakdowns, charge_model_result)
      charge_model_result.grouped_results.each_with_object({}) do |grouped_result, memo|
        grouped_by = grouped_result.grouped_by || {}
        next if memo.key?(grouped_by)

        grouped_by_keys = grouped_by.keys
        memo[grouped_by] = Array(breakdowns)
          .lazy
          .select { |b| b[:groups].slice(*grouped_by_keys) == grouped_by }
          .map { |b| {groups: b[:groups].except(*grouped_by_keys), value: b[:value]} }
          .to_a
      end
    end

    def filter_non_persistable_fees_for_caching(charge_fees)
      return charge_fees unless skip_caching_of_non_persistable_fee?

      charge_fees.filter { |f| should_persist_fee?(f, charge_fees) }
    end

    def init_fee(amount_result, properties:, charge_filter:, adjusted:)
      # NOTE: Build fee for case when there is adjusted fee and units or amount has been adjusted (see applicable_adjusted_fee method).
      # Base fee creation flow handles case when only name has been adjusted
      if adjusted
        adjustement_result = Fees::InitFromAdjustedChargeFeeService.call(
          adjusted_fee: adjusted,
          boundaries:,
          properties:
        )
        unless adjustement_result.success?
          result.fail_with_error!(adjustement_result.error)
          return nil
        end

        return adjustement_result.fee
      end

      # Prevent trying to create a fee with negative units or amount.
      if amount_result.units.negative? || amount_result.amount.negative?
        amount_result.amount = amount_result.unit_amount = BigDecimal(0)
        amount_result.full_units_number = amount_result.units = BigDecimal(0)
      end

      # NOTE: amount_result should be a BigDecimal, we need to round it
      # to the currency decimals and transform it into currency cents
      if charge.applied_pricing_unit
        pricing_unit_usage = PricingUnitUsage.build_from_fiat_amounts(
          amount: amount_result.amount,
          unit_amount: amount_result.unit_amount,
          applied_pricing_unit: charge.applied_pricing_unit
        )

        amount_cents, precise_amount_cents, unit_amount_cents, precise_unit_amount = pricing_unit_usage
          .to_fiat_currency_cents(currency)
          .values_at(:amount_cents, :precise_amount_cents, :unit_amount_cents, :precise_unit_amount)
      else
        pricing_unit_usage = nil
        rounded_amount = amount_result.amount.round(currency.exponent)
        amount_cents = rounded_amount * currency.subunit_to_unit
        precise_amount_cents = amount_result.amount * currency.subunit_to_unit.to_d
        unit_amount_cents = amount_result.unit_amount * currency.subunit_to_unit
        precise_unit_amount = amount_result.unit_amount
      end

      units = if current_usage && (charge.pay_in_advance? || charge.prorated?)
        amount_result.current_usage_units
      elsif charge.prorated?
        amount_result.full_units_number.nil? ? amount_result.units : amount_result.full_units_number
      else
        amount_result.units
      end

      new_fee = Fee.new(
        invoice:,
        organization_id: subscription.organization_id,
        billing_entity_id: subscription.applicable_billing_entity_id,
        subscription:,
        charge:,
        amount_cents:,
        precise_amount_cents:,
        amount_currency: currency,
        fee_type: :charge,
        invoiceable_type: "Charge",
        invoiceable: charge,
        units:,
        total_aggregated_units: amount_result.total_aggregated_units || units,
        properties: filtered_for_charge_boundaries(boundaries.to_h),
        events_count: amount_result.count,
        payment_status: :pending,
        taxes_amount_cents: 0,
        taxes_precise_amount_cents: 0.to_d,
        unit_amount_cents:,
        precise_unit_amount:,
        amount_details: amount_result.amount_details,
        grouped_by: amount_result.grouped_by || {},
        charge_filter: charge_filter&.persisted? ? charge_filter : nil,
        pricing_unit_usage:
      )

      unless charge.invoiceable?
        new_fee.pay_in_advance = charge.pay_in_advance?
      end

      if !current_usage && (adjusted = adjusted_fee(charge_filter:, grouped_by: amount_result.grouped_by))&.adjusted_display_name?
        new_fee.invoice_display_name = adjusted.invoice_display_name
      end

      if apply_taxes
        taxes_result = Fees::ApplyTaxesService.call(fee: new_fee, plan: @plan, customer: @customer)
        taxes_result.raise_if_error!
      end

      new_fee
    end

    def should_persist_fee?(fee, fees)
      return true if context == :recurring
      return true if fee.units != 0 || fee.amount_cents != 0 || fee.events_count != 0
      return true if adjusted_fee(charge_filter: fee.charge_filter, grouped_by: fee.grouped_by).present?
      return true if fee.true_up_parent_fee.present?

      fees.any? { |f| f.true_up_parent_fee == fee }
    end

    def adjusted_fee(charge_filter:, grouped_by:)
      return if @skip_adjusted_fees
      @adjusted_fee ||= {}

      key = [
        charge_filter&.id,
        (grouped_by || {}).map do |k, v|
          "#{k}-#{v}"
        end.sort.join("|")
      ].compact.join("|")
      key = "default" if key.blank?

      return @adjusted_fee[key] if @adjusted_fee.key?(key)

      scope = AdjustedFee
        .where(invoice:, subscription:, charge:, charge_filter:, fee_type: :charge)
        .where("(properties->>'charges_from_datetime')::timestamptz = ?", boundaries.charges_from_datetime&.iso8601(3))
        .where("(properties->>'charges_to_datetime')::timestamptz = ?", boundaries.charges_to_datetime&.iso8601(3))

      scope = if grouped_by.present?
        scope.where(grouped_by:)
      else
        scope.where(grouped_by: {})
      end

      @adjusted_fee[key] = scope.first
    end

    def init_true_up_fee
      fee = result.fees.find { |f| f.charge_filter_id.nil? }

      if charge.applied_pricing_unit
        used_amount_cents = result.fees.map(&:pricing_unit_usage).sum(&:amount_cents)
        used_precise_amount_cents = result.fees.map(&:pricing_unit_usage).sum(&:precise_amount_cents)
      else
        used_amount_cents = result.fees.sum(&:amount_cents)
        used_precise_amount_cents = result.fees.sum(&:precise_amount_cents)
      end

      true_up_fee = Fees::CreateTrueUpService.call(fee:, used_amount_cents:, used_precise_amount_cents:).true_up_fee
      result.fees << true_up_fee if true_up_fee
    end

    def apply_charge_model(aggregation_result:, properties:)
      ChargeModels::Factory.new_instance(
        chargeable: charge,
        aggregation_result:,
        properties:,
        period_ratio: calculate_period_ratio,
        calculate_projected_usage:
      ).apply
    end

    def options(properties)
      {
        free_units_per_events: properties["free_units_per_events"].to_i,
        free_units_per_total_aggregation: BigDecimal(properties["free_units_per_total_aggregation"] || 0),
        is_current_usage: current_usage,
        is_pay_in_advance: charge.pay_in_advance?
      }
    end

    def already_billed?
      existing_fees = if invoice
        invoice.fees.where(charge_id: charge.id, subscription_id: subscription.id)
      else
        Fee.where(
          charge_id: charge.id,
          subscription_id: subscription.id,
          invoice_id: nil,
          pay_in_advance_event_id: nil
        ).where(
          "(properties->>'charges_from_datetime')::timestamptz = ?", boundaries.charges_from_datetime&.iso8601(3)
        ).where(
          "(properties->>'charges_to_datetime')::timestamptz = ?", boundaries.charges_to_datetime&.iso8601(3)
        )
      end

      return false if existing_fees.blank?

      result.fees = existing_fees
      true
    end

    def aggregator(charge_filter:)
      aggregate = true
      aggregate = filtered_aggregations.include?(charge_filter&.id) unless filtered_aggregations.nil?

      BillableMetrics::AggregationFactory.new_instance(
        charge:,
        current_usage:,
        subscription:,
        boundaries: {
          from_datetime: boundaries.charges_from_datetime,
          to_datetime: boundaries.charges_to_datetime,
          charges_duration: boundaries.charges_duration,
          max_timestamp: boundaries.max_timestamp
        },
        filters: aggregation_filters(charge_filter:),
        bypass_aggregation: !aggregate
      )
    end

    def persist_recurring_value(aggregation_results, charge_filter, breakdowns_by_group)
      return if current_usage

      # NOTE: Only weighted sum and custom aggregations are setting this value
      return unless aggregation_results.first&.recurring_updated_at

      result.cached_aggregations ||= []

      # NOTE: persist current recurring value for next period
      aggregation_results.each do |aggregation_result|
        grouped_by = aggregation_result.grouped_by || {}

        result.cached_aggregations << CachedAggregation.find_or_initialize_by(
          organization_id: billable_metric.organization_id,
          external_subscription_id: subscription.external_id,
          charge_id: charge.id,
          charge_filter_id: charge_filter&.id,
          grouped_by:,
          timestamp: aggregation_result.recurring_updated_at
        ) do |aggregation|
          aggregation.current_aggregation = aggregation_result.total_aggregated_units || aggregation_result.aggregation
          aggregation.current_amount = aggregation_result.custom_aggregation&.[](:amount)
          aggregation.presentation_breakdowns = breakdowns_by_group.fetch(grouped_by, [])
          aggregation.save!
        end
      end
    end

    def grouped_by_keys(charge_filter: nil)
      model = charge_filter.presence || charge
      grouped_by_keys = model.pricing_group_keys&.dup || []
      if charge.accepts_target_wallet && !grouped_by_keys.include?("target_wallet_code")
        grouped_by_keys << "target_wallet_code"
      end
      grouped_by_keys if grouped_by_keys.present? && !usage_filters.skip_grouping
    end

    def aggregation_filters(charge_filter: nil)
      filters = {charge_id: charge.id}

      grouped_by_keys = grouped_by_keys(charge_filter:)
      filters[:grouped_by] = grouped_by_keys if grouped_by_keys.present?

      presentation_group_keys_values = charge.presentation_group_keys_values
      if presentation_group_keys_values.present?
        filters[:presentation_by] = presentation_group_keys_values & (usage_filters.filter_by_presentation || presentation_group_keys_values)
      end

      if charge_filter.present?
        result = ChargeFilters::MatchingAndIgnoredService.call(charge:, filter: charge_filter)
        filters[:charge_filter] = charge_filter
        filters[:matching_filters] = result.matching_filters
        filters[:ignored_filters] = result.ignored_filters
      end

      if usage_filters.filter_by_group.present?
        # when pricing group keys on a charge are "workspace" and "user", and filter_by_group is {"workspace" => ["A"]},
        # we want to remove the grouping keys "workspace", but keep the grouping key "user", so the usage will still be granular within the workspace
        usage_filters.filter_by_group.keys.each { |key| filters[:grouped_by]&.delete(key) }
        # NOTE: filters[:matching_filters] may come from ChargeFilter#to_h_with_all_values
        # which returns a frozen hash, so we must not mutate it in place.
        # expected matching_filters format is { "workspace" => ["A", "B"], "user" => ["U1", "U2"] }
        filters[:matching_filters] = (filters[:matching_filters] || {}).merge(usage_filters.filter_by_group)
      end

      filters
    end

    def calculate_period_ratio
      from_date = boundaries.charges_from_datetime.to_date
      to_date = boundaries.charges_to_datetime.to_date
      current_date = Time.current.to_date

      total_days = (to_date - from_date).to_i + 1

      charges_duration = boundaries.charges_duration || total_days

      return 1.0 if current_date >= to_date
      return 0.0 if current_date < from_date

      days_passed = (current_date - from_date).to_i + 1

      ratio = days_passed.fdiv(charges_duration)
      ratio.clamp(0.0, 1.0)
    end

    def filtered_for_charge_boundaries(boundaries)
      properties = boundaries.to_h
      properties["fixed_charges_from_datetime"] = nil
      properties["fixed_charges_to_datetime"] = nil
      properties["fixed_charges_duration"] = nil
      properties
    end
  end
end
