# frozen_string_literal: true

module Types
  module PricingUnits
    class CreateInput < Types::BaseInputObject
      argument :code, String, required: true
      argument :description, String, required: false
      argument :name, String, required: true
      argument :short_name, String, required: true
    end
  end
end
