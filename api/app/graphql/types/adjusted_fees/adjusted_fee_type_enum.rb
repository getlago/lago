# frozen_string_literal: true

module Types
  module AdjustedFees
    class AdjustedFeeTypeEnum < Types::BaseEnum
      AdjustedFee::ADJUSTED_FEE_TYPES.each do |type|
        value type
      end
    end
  end
end
