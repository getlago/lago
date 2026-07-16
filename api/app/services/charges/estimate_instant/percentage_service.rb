# frozen_string_literal: true

module Charges
  module EstimateInstant
    class PercentageService < BaseService
      Result = BaseResult[:units, :amount]

      def initialize(properties:, units:)
        @properties = properties
        @units = units
        super
      end

      def call
        result.units = units
        if units.negative?
          result.units = 0
          result.amount = 0
          return result
        end

        amount = units * rate / 100
        amount += fixed_amount
        amount = amount.clamp(per_transaction_min_amount, per_transaction_max_amount)

        result.amount = amount
        result
      end

      private

      attr_reader :properties, :units

      def rate
        BigDecimal(properties["rate"].to_s)
      end

      def per_transaction_max_amount
        return nil if properties["per_transaction_max_amount"].blank?
        BigDecimal(properties["per_transaction_max_amount"].to_s)
      end

      def fixed_amount
        BigDecimal((properties["fixed_amount"] || 0).to_s)
      end

      def per_transaction_min_amount
        return nil if properties["per_transaction_min_amount"].blank?
        BigDecimal(properties["per_transaction_min_amount"].to_s)
      end
    end
  end
end
