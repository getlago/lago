# frozen_string_literal: true

module Types
  module ChargeModels
    class GraduatedPercentageRangeInput < Types::BaseInputObject
      argument :from_value, Float, required: true
      argument :to_value, Float, required: false

      argument :flat_amount, String, required: true
      argument :rate, String, required: true
    end
  end
end
