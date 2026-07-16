# frozen_string_literal: true

module Types
  module Entitlement
    class PrivilegeConfigObject < Types::BaseObject
      description "Configuration object for privileges"

      field :select_options, [String], null: true, description: "Available options for select type privileges"
    end
  end
end
