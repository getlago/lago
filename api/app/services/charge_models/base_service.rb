# frozen_string_literal: true

module ChargeModels
  class BaseService < ::BaseService
    Result = BaseResult[
      :units, # Result of the aggregation
      :current_usage_units, # Number of units for current usage (mainly used for prorated or in advance charges)
      :full_units_number, # Total number of aggregated units ignoring proration
      :count, # Total number of events used for the aggregation
      :amount, # Amount result of the charge model applied on the units
      :unit_amount, # Amount per unit
      :amount_details, # Details of the amount calculation. Depends on the charge model.
      :total_aggregated_units, # Total number of aggregated units in the case of a weighted sum aggregation
      :grouped_by, # Groups applied on event properties for the aggregation
      :grouped_results, # Array containing the result for compatibility with grouped aggregation
      :projected_amount, # Projected total amount for the billing period
      :projected_units # Projected total units for the billing period
    ]

    def self.apply(...)
      new(...).apply
    end

    def initialize(charge:, aggregation_result:, properties:, period_ratio: nil, calculate_projected_usage: false)
      super(nil)
      @charge = charge
      @aggregation_result = aggregation_result
      @properties = properties
      @period_ratio = period_ratio
      @calculate_projected_usage = calculate_projected_usage
    end

    def apply
      result.units = aggregation_result.aggregation
      result.current_usage_units = aggregation_result.current_usage_units
      result.full_units_number = aggregation_result.full_units_number
      result.count = aggregation_result.count
      result.amount = compute_amount
      result.unit_amount = unit_amount
      result.amount_details = amount_details

      if aggregation_result.total_aggregated_units
        result.total_aggregated_units = aggregation_result.total_aggregated_units
      end

      if calculate_projected_usage
        result.projected_units = projected_units
        result.projected_amount = compute_projected_amount
      end

      result.grouped_results = [result]
      result
    end

    protected

    attr_accessor :charge, :aggregation_result, :properties, :period_ratio, :calculate_projected_usage

    delegate :units, to: :result
    delegate :grouped_by, to: :aggregation_result

    def projected_units
      return BigDecimal("0") if units.nil? || units.zero?

      begin
        (period_ratio > 0) ? (units / BigDecimal(period_ratio.to_s)).round(2) : BigDecimal("0")
      rescue => e
        Rails.logger.error "Error calculating projected_units in #{self.class}: #{e.message}"
        BigDecimal("0")
      end
    end

    def compute_projected_amount
      raise NotImplementedError, "#{self.class} must implement #compute_projected_amount"
    end

    def compute_amount
      raise NotImplementedError, "#{self.class} must implement #compute_amount"
    end

    def unit_amount
      raise NotImplementedError, "#{self.class} must implement #unit_amount"
    end

    def amount_details
      {}
    end
  end
end
