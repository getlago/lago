# frozen_string_literal: true

module Types
  module Entitlement
    class PrivilegeConfigInput < Types::BaseInputObject
      description "Input for privilege configuration"

      argument :select_options, [String], required: false, description: "Available options for select type privileges"
    end
  end
end
