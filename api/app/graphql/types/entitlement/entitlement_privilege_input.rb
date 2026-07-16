# frozen_string_literal: true

module Types
  module Entitlement
    class EntitlementPrivilegeInput < Types::BaseInputObject
      description "Input for updating a plan entitlement privilege value"

      argument :privilege_code, String, required: true
      argument :value, String, required: true
    end
  end
end
