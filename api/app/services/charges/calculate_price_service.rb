# frozen_string_literal: true

module Charges
  class CalculatePriceService < BaseService
    Result = BaseResult[:charge_amount_cents, :subscription_amount_cents, :total_amount_cents]
    AggregationResult = Struct.new(:grouped_by, :aggregator, :aggregations, :aggregation, :total_aggregated_units, :current_usage_units, :full_units_number, :precise_total_amount_cents, :custom_aggregation, :options)

    def initialize(units:, charge:, charge_filter: nil)
      @units = BigDecimal(units || 0)
      @charge = charge
      @charge_filter = charge_filter
      @billable_metric = charge&.billable_metric

      super
    end

    def call
      return result.not_found_failure!(resource: "charge") unless charge

      result.charge_amount_cents = calculate_charge_amount
      result.subscription_amount_cents = BigDecimal(plan.amount_cents)
      result.total_amount_cents = result.charge_amount_cents + result.subscription_amount_cents
      result
    end

    private

    attr_reader :units, :charge, :charge_filter, :billable_metric

    delegate :plan, to: :charge

    def calculate_charge_amount
      return 0 unless charge

      properties = charge_filter&.properties ||
        charge.properties.presence ||
        ChargeModels::BuildDefaultPropertiesService.call(charge.charge_model)

      filtered_properties = ChargeModels::FilterPropertiesService.call(chargeable: charge, properties:).properties

      charge_model = ChargeModels::Factory.new_instance(
        chargeable: charge,
        aggregation_result:,
        properties: filtered_properties
      )

      charge_model.apply.amount
    end

    def aggregation_result
      AggregationResult.new(nil, nil, nil, units, units, units, units, 0, nil, running_total: [])
    end
  end
end
