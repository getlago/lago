# frozen_string_literal: true

module Types
  module Entitlement
    class SubscriptionEntitlementPrivilegeObject < Types::BaseObject
      field :code, String, null: false
      field :config, Types::Entitlement::PrivilegeConfigObject, null: false
      field :name, String, null: true
      field :value_type, Types::Entitlement::PrivilegeValueTypeEnum, null: false

      field :value, String, null: true

      def value
        # NOTE: If the boolean `true`/`false` were sent to via the API, ActiveRecord will store them as `"t"`/`"f"`
        #       We convert them to full words, as string, for the frontent
        if object.value_type == "boolean"
          return "false" if object.value == "f"
          return "true" if object.value == "t"
        end

        object.value
      end
    end
  end
end
