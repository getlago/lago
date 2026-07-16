# frozen_string_literal: true

module Types
  module FixedCharges
    class ChargeModelEnum < Types::BaseEnum
      graphql_name "FixedChargeChargeModelEnum"

      FixedCharge::CHARGE_MODELS.keys.each do |type|
        value type
      end
    end
  end
end
