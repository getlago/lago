# frozen_string_literal: true

module Types
  module Charges
    class ChargeModelEnum < Types::BaseEnum
      Charge::CHARGE_MODELS.each do |type|
        value type
      end
    end
  end
end
