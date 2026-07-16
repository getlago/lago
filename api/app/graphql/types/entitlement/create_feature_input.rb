# frozen_string_literal: true

module Types
  module Entitlement
    class CreateFeatureInput < Types::BaseInputObject
      description "Input for creating a feature"

      argument :code, String, required: true, description: "The code of the feature"
      argument :description, String, required: false, description: "The description of the feature"
      argument :name, String, required: false, description: "The name of the feature"
      argument :privileges, [UpdatePrivilegeInput], required: true, description: "The privileges configuration"
    end
  end
end
