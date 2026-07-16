# frozen_string_literal: true

module Types
  module Subscriptions
    class NextSubscriptionTypeEnum < Types::BaseEnum
      value "upgrade"
      value "downgrade"
    end
  end
end
