# frozen_string_literal: true

module Types
  module PricingUnits
    class UpdateInput < Types::BaseInputObject
      argument :id, ID, required: true

      argument :description, String, required: false
      argument :name, String, required: false
      argument :short_name, String, required: false
    end
  end
end
