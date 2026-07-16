# frozen_string_literal: true

module Types
  module Entitlement
    class PlanEntitlementPrivilegeObject < Types::BaseObject
      field :code, String, null: false
      field :config, Types::Entitlement::PrivilegeConfigObject, null: false
      field :name, String, null: true
      field :value_type, Types::Entitlement::PrivilegeValueTypeEnum, null: false

      field :value, String, null: false

      def code
        object.privilege.code
      end

      def config
        object.privilege.config
      end

      def name
        object.privilege.name
      end

      def value_type
        object.privilege.value_type
      end

      def value
        # NOTE: If the boolean `true`/`false` were sent to via the API, ActiveRecord will store them as `"t"`/`"f"`
        #       We convert them to full words, as string, for the frontent
        if object.privilege.value_type == "boolean"
          return "false" if object.value == "f"
          return "true" if object.value == "t"
        end

        object.value
      end
    end
  end
end
