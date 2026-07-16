# frozen_string_literal: true

module Validators
  module RangeBoundsValidator
    def valid_bounds?(range, index, next_from_value)
      from = BigDecimal(range[:from_value].to_s)
      next_from = BigDecimal(next_from_value.to_s)
      valid_from = from == next_from || from == next_from + 1

      valid_from && (
        index == (ranges.size - 1) && range[:to_value].nil? ||
        index < (ranges.size - 1) && BigDecimal((range[:to_value] || 0).to_s) > from
      )
    end
  end
end
