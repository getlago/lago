# frozen_string_literal: true

module Validators
  class DecimalAmountService
    def self.valid_amount?(amount)
      new(amount).valid_amount?
    end

    def self.valid_positive_amount?(amount)
      new(amount).valid_positive_amount?
    end

    def initialize(amount)
      @amount = amount
    end

    def valid_amount?
      return false unless valid_decimal?

      decimal_amount.zero? || decimal_amount.positive?
    end

    def valid_positive_amount?
      return false unless valid_decimal?

      BigDecimal(amount).positive?
    end

    def valid_decimal?
      # NOTE: as we want to be the more precise with decimals, we only
      # accept amount that are in string to avoid float bad parsing
      # and use BigDecimal as a source of truth when computing amounts
      return false unless amount.is_a?(String)

      @decimal_amount ||= BigDecimal(amount)

      decimal_amount.present? &&
        decimal_amount.finite?
    # NOTE: If BigDecimal can't parse the amount, it will trigger
    # an ArgumentError is the type is not a numeric, ei: 'foo'
    # a TypeError is the amount is nil
    rescue ArgumentError, TypeError
      false
    end

    private

    attr_reader :amount, :decimal_amount
  end
end
