# frozen_string_literal: true

module V1
  module Entitlement
    class SubscriptionEntitlementSerializer < ModelSerializer
      def serialize
        {
          code: model.code,
          name: model.name,
          description: model.description,
          privileges:,
          overrides:
        }
      end

      private

      def privileges
        model.privileges.map do
          {
            code: it.code,
            name: it.name,
            value_type: it.value_type,
            value: Utils::Entitlement.cast_value(it.value, it.value_type),
            plan_value: Utils::Entitlement.cast_value(it.plan_value, it.value_type),
            override_value: Utils::Entitlement.cast_value(it.subscription_value, it.value_type),
            config: it.config
          }
        end
      end

      def overrides
        model.privileges.filter_map do
          [it.code, Utils::Entitlement.cast_value(it.subscription_value, it.value_type)] if it.subscription_value
        end.to_h
      end
    end
  end
end
