# frozen_string_literal: true

module Types
  module Taxes
    class CreateInput < Types::BaseInputObject
      graphql_name "TaxCreateInput"

      argument :code, String, required: true
      argument :description, String, required: false
      argument :name, String, required: true
      argument :rate, Float, required: true
    end
  end
end
