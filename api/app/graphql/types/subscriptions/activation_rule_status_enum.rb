# frozen_string_literal: true

module Types
  module Subscriptions
    class ActivationRuleStatusEnum < Types::BaseEnum
      Subscription::ActivationRule::STATUSES.each_key do |status|
        value status
      end
    end
  end
end
