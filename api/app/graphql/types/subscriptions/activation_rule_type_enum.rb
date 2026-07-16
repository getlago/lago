# frozen_string_literal: true

module Types
  module Subscriptions
    class ActivationRuleTypeEnum < Types::BaseEnum
      Subscription::ActivationRule::TYPES.each_key do |type|
        value type
      end
    end
  end
end
