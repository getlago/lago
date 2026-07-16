# frozen_string_literal: true

module Types
  module ChargeModels
    class GraduatedRangeInput < Types::BaseInputObject
      argument :from_value, Float, required: true
      argument :to_value, Float, required: false

      argument :flat_amount, String, required: true
      argument :per_unit_amount, String, required: true
    end
  end
end
