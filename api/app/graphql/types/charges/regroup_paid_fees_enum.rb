# frozen_string_literal: true

module Types
  module Charges
    class RegroupPaidFeesEnum < Types::BaseEnum
      Charge::REGROUPING_PAID_FEES_OPTIONS.each do |type|
        value type
      end
    end
  end
end
