# frozen_string_literal: true

module ChargeModels
  class GroupedService < ChargeModels::BaseService
    Result = BaseResult[
      :grouped_results,
      :amount,
      :units,
      :projected_amount,
      :projected_units
    ]

    def initialize(charge_model:, charge:, aggregation_result:, properties:, period_ratio:, calculate_projected_usage: false)
      super(charge:, aggregation_result:, properties:, period_ratio:, calculate_projected_usage:)
      @charge_model = charge_model
    end

    def apply
      result.grouped_results = aggregation_result.aggregations.map do |aggregation|
        aggregation.aggregator = aggregation_result.aggregator
        group_result = charge_model.apply(
          charge:,
          aggregation_result: aggregation,
          properties:,
          period_ratio:,
          calculate_projected_usage:
        )
        group_result.grouped_by = aggregation.grouped_by
        group_result
      end

      result.amount = result.grouped_results.sum(&:amount)
      result.units = result.grouped_results.sum(&:units)

      if calculate_projected_usage
        result.projected_amount = result.grouped_results.sum(&:projected_amount)
        result.projected_units = result.grouped_results.sum(&:projected_units)
      end

      result
    end

    protected

    attr_accessor :charge_model
  end
end
