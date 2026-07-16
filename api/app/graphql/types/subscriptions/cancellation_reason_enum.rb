# frozen_string_literal: true

module Types
  module Subscriptions
    class CancellationReasonEnum < Types::BaseEnum
      Subscription::CANCELLATION_REASONS.each_key do |reason|
        value reason
      end
    end
  end
end
