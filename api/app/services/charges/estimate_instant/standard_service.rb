# frozen_string_literal: true

module Charges
  module EstimateInstant
    class StandardService < BaseService
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

        result.amount = units * amount
        result
      end

      private

      attr_reader :properties, :units

      def amount
        BigDecimal((properties["amount"] || 0).to_s)
      end
    end
  end
end
