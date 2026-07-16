# frozen_string_literal: true

module Types
  module Entitlement
    class UpdateFeatureInput < Types::BaseInputObject
      description "Input for updating a feature"

      argument :id, ID, required: true, description: "The ID of the feature to update"

      argument :description, String, required: false, description: "The description of the feature"
      argument :name, String, required: false, description: "The name of the feature"
      argument :privileges, [UpdatePrivilegeInput], required: true, description: "The privileges configuration"
    end
  end
end
