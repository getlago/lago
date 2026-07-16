# frozen_string_literal: true

module Types
  module Entitlement
    class EntitlementInput < Types::BaseInputObject
      description "Input for updating a plan entitlement"

      argument :feature_code, String, required: true
      argument :privileges, [EntitlementPrivilegeInput], required: false, description: "The privileges configuration"
    end
  end
end
