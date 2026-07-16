# frozen_string_literal: true

module Types
  module Entitlement
    class UpdatePrivilegeInput < Types::BaseInputObject
      description "Input for updating a privilege"

      argument :code, String, required: true
      argument :config, Types::Entitlement::PrivilegeConfigInput, required: false
      argument :name, String, required: false
      argument :value_type, PrivilegeValueTypeEnum, required: false
    end
  end
end
